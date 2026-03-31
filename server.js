/**
 * QuizMaster Pro — Backend (Node.js / Express)
 *
 * Routes:
 *   GET  /api/topics            – list all topics with question count
 *   GET  /api/questions/:topic  – questions for a topic
 *   POST /api/quiz/start        – create session, return shuffled questions
 *   POST /api/quiz/submit       – save answers, compute score
 *   GET  /api/leaderboard       – top 10 results per topic
 *   GET  /api/history/:name     – past sessions for a player
 *
 * Install: npm install express cors pg dotenv
 * Run:     node server.js
 */

const express = require("express");
const cors    = require("cors");
const { Pool } = require("pg");
require("dotenv").config();

const app  = express();
const PORT = process.env.PORT || 4000;

// ─── DB POOL ──────────────────────────────────────────────────────────
const pool = new Pool({
  host:     process.env.DB_HOST     || "localhost",
  port:     Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME     || "quizmaster",
  user:     process.env.DB_USER     || "postgres",
  password: process.env.DB_PASSWORD || "",
  ssl:      process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
});

// ─── MIDDLEWARE ────────────────────────────────────────────────────────
app.use(cors({ origin: process.env.FRONTEND_URL || "http://localhost:5173" }));
app.use(express.json());

// ─── HELPERS ─────────────────────────────────────────────────────────
const shuffle = (arr) => {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};

const gradeFor = (pct) => {
  if (pct >= 90) return "A+";
  if (pct >= 80) return "A";
  if (pct >= 70) return "B";
  if (pct >= 50) return "C";
  return "F";
};

// ─── ROUTES ───────────────────────────────────────────────────────────

/**
 * GET /api/health
 * Simple liveness check.
 */
app.get("/api/health", (_, res) => res.json({ status: "ok" }));

/**
 * GET /api/topics
 * Returns all topics with their question count.
 */
app.get("/api/topics", async (_, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT t.id, t.key, t.icon, t.description AS desc,
             COUNT(q.id)::int AS count
      FROM topics t
      LEFT JOIN questions q ON q.topic_id = t.id
      GROUP BY t.id
      ORDER BY t.sort_order
    `);
    res.json({ topics: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "DB error" });
  }
});

/**
 * GET /api/questions/:topicKey
 * Returns all questions for a topic (opts array, ans index).
 */
app.get("/api/questions/:topicKey", async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT q.id, q.question AS q,
             ARRAY[q.opt_a, q.opt_b, q.opt_c, q.opt_d] AS opts,
             q.correct_index AS ans
      FROM questions q
      JOIN topics t ON t.id = q.topic_id
      WHERE t.key = $1
      ORDER BY RANDOM()
    `, [req.params.topicKey]);

    if (!rows.length) return res.status(404).json({ error: "Topic not found" });
    res.json({ questions: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "DB error" });
  }
});

/**
 * POST /api/quiz/start
 * Body: { topic, numQ, timePerQ, playerName }
 * Creates a quiz_sessions row; returns sessionId + shuffled questions.
 */
app.post("/api/quiz/start", async (req, res) => {
  const { topic, numQ = 10, timePerQ = 30, playerName } = req.body;

  if (!topic || !playerName) {
    return res.status(400).json({ error: "topic and playerName are required" });
  }

  try {
    // Resolve topic id
    const topicRes = await pool.query("SELECT id FROM topics WHERE key = $1", [topic]);
    if (!topicRes.rows.length) return res.status(404).json({ error: "Topic not found" });
    const topicId = topicRes.rows[0].id;

    // Fetch questions
    const { rows: allQs } = await pool.query(`
      SELECT id, question AS q,
             ARRAY[opt_a, opt_b, opt_c, opt_d] AS opts,
             correct_index AS ans
      FROM questions
      WHERE topic_id = $1
    `, [topicId]);

    const questions = shuffle(allQs).slice(0, numQ);

    // Create session
    const { rows: [session] } = await pool.query(`
      INSERT INTO quiz_sessions (player_name, topic_id, num_questions, time_per_q, started_at)
      VALUES ($1, $2, $3, $4, NOW())
      RETURNING id AS "sessionId"
    `, [playerName, topicId, numQ, timePerQ]);

    res.json({ sessionId: session.sessionId, questions });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "DB error" });
  }
});

/**
 * POST /api/quiz/submit
 * Body: { sessionId, answers: [{selected, correct}], elapsed }
 * Persists answers, updates session with score.
 */
app.post("/api/quiz/submit", async (req, res) => {
  const { sessionId, answers = [], elapsed = 0 } = req.body;

  if (!sessionId) return res.status(400).json({ error: "sessionId required" });

  try {
    // Fetch session
    const sessionRes = await pool.query(
      "SELECT * FROM quiz_sessions WHERE id = $1", [sessionId]
    );
    if (!sessionRes.rows.length) return res.status(404).json({ error: "Session not found" });
    const session = sessionRes.rows[0];

    const correct  = answers.filter(a => a.correct).length;
    const numQ     = session.num_questions;
    const pct      = Math.round((correct / numQ) * 100);
    const grade    = gradeFor(pct);

    // Update session
    await pool.query(`
      UPDATE quiz_sessions
      SET correct = $1, wrong = $2, score_pct = $3, grade = $4,
          elapsed_secs = $5, completed_at = NOW()
      WHERE id = $6
    `, [correct, numQ - correct, pct, grade, elapsed, sessionId]);

    // Insert individual answer records
    if (answers.length) {
      const vals = answers
        .map((a, i) => `(${sessionId}, ${i + 1}, ${a.selected}, ${a.correct})`)
        .join(", ");
      await pool.query(`
        INSERT INTO quiz_answers (session_id, question_order, selected_index, is_correct)
        VALUES ${vals}
      `);
    }

    res.json({ correct, numQ, pct, grade });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "DB error" });
  }
});

/**
 * GET /api/leaderboard?topic=JavaScript&limit=10
 * Top scores per topic.
 */
app.get("/api/leaderboard", async (req, res) => {
  const { topic, limit = 10 } = req.query;
  try {
    const params = [Number(limit)];
    let topicFilter = "";
    if (topic) {
      topicFilter = " AND t.key = $2";
      params.push(topic);
    }

    const { rows } = await pool.query(`
      SELECT qs.player_name, t.key AS topic, t.icon,
             qs.score_pct, qs.grade, qs.correct, qs.num_questions,
             qs.elapsed_secs, qs.completed_at
      FROM quiz_sessions qs
      JOIN topics t ON t.id = qs.topic_id
      WHERE qs.completed_at IS NOT NULL ${topicFilter}
      ORDER BY qs.score_pct DESC, qs.elapsed_secs ASC
      LIMIT $1
    `, params);

    res.json({ leaderboard: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "DB error" });
  }
});

/**
 * GET /api/history/:playerName
 * Past sessions for a named player.
 */
app.get("/api/history/:playerName", async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT qs.id, t.key AS topic, t.icon,
             qs.score_pct, qs.grade, qs.correct, qs.num_questions,
             qs.elapsed_secs, qs.completed_at
      FROM quiz_sessions qs
      JOIN topics t ON t.id = qs.topic_id
      WHERE LOWER(qs.player_name) = LOWER($1)
        AND qs.completed_at IS NOT NULL
      ORDER BY qs.completed_at DESC
      LIMIT 50
    `, [req.params.playerName]);

    res.json({ history: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "DB error" });
  }
});

// ─── START ─────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`✅  QuizMaster API running at http://localhost:${PORT}`);
});

module.exports = app; // for testing
