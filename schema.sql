-- ══════════════════════════════════════════════════════════════
--  QuizMaster Pro — PostgreSQL Schema + Seed Data
--  Run with:  psql -d quizmaster -f schema.sql
-- ══════════════════════════════════════════════════════════════

-- ─── EXTENSIONS ───────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── RESET (dev only – comment out in production) ─────────────
DROP TABLE IF EXISTS quiz_answers  CASCADE;
DROP TABLE IF EXISTS quiz_sessions CASCADE;
DROP TABLE IF EXISTS questions     CASCADE;
DROP TABLE IF EXISTS topics        CASCADE;

-- ══════════════════════════════════════════════════════════════
--  TABLE: topics
-- ══════════════════════════════════════════════════════════════
CREATE TABLE topics (
  id          SERIAL PRIMARY KEY,
  key         VARCHAR(60)  NOT NULL UNIQUE,   -- "JavaScript"
  icon        VARCHAR(8)   NOT NULL,          -- "⚡"
  description VARCHAR(120) NOT NULL,          -- "ES6+, Closures, Async"
  sort_order  SMALLINT     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════
--  TABLE: questions
-- ══════════════════════════════════════════════════════════════
CREATE TABLE questions (
  id            SERIAL PRIMARY KEY,
  topic_id      INT          NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  question      TEXT         NOT NULL,
  opt_a         TEXT         NOT NULL,
  opt_b         TEXT         NOT NULL,
  opt_c         TEXT         NOT NULL,
  opt_d         TEXT         NOT NULL,
  correct_index SMALLINT     NOT NULL CHECK (correct_index BETWEEN 0 AND 3),
  difficulty    VARCHAR(10)  NOT NULL DEFAULT 'medium'
                             CHECK (difficulty IN ('easy','medium','hard')),
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_questions_topic ON questions(topic_id);

-- ══════════════════════════════════════════════════════════════
--  TABLE: quiz_sessions
-- ══════════════════════════════════════════════════════════════
CREATE TABLE quiz_sessions (
  id            SERIAL PRIMARY KEY,
  player_name   VARCHAR(80)  NOT NULL,
  topic_id      INT          NOT NULL REFERENCES topics(id),
  num_questions SMALLINT     NOT NULL DEFAULT 10,
  time_per_q    SMALLINT     NOT NULL DEFAULT 30,   -- 0 = no limit
  correct       SMALLINT,
  wrong         SMALLINT,
  score_pct     SMALLINT,
  grade         CHAR(2),
  elapsed_secs  INT,
  started_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  completed_at  TIMESTAMPTZ
);

CREATE INDEX idx_sessions_player ON quiz_sessions(LOWER(player_name));
CREATE INDEX idx_sessions_topic  ON quiz_sessions(topic_id);
CREATE INDEX idx_sessions_score  ON quiz_sessions(score_pct DESC NULLS LAST);

-- ══════════════════════════════════════════════════════════════
--  TABLE: quiz_answers
-- ══════════════════════════════════════════════════════════════
CREATE TABLE quiz_answers (
  id             SERIAL PRIMARY KEY,
  session_id     INT         NOT NULL REFERENCES quiz_sessions(id) ON DELETE CASCADE,
  question_order SMALLINT    NOT NULL,   -- 1-based position in this session
  selected_index SMALLINT    NOT NULL,   -- -1 = timed out, 0-3 = A/B/C/D
  is_correct     BOOLEAN     NOT NULL,
  answered_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_answers_session ON quiz_answers(session_id);

-- ══════════════════════════════════════════════════════════════
--  SEED: topics
-- ══════════════════════════════════════════════════════════════
INSERT INTO topics (key, icon, description, sort_order) VALUES
  ('JavaScript',        '⚡', 'ES6+, Closures, Async',          1),
  ('Python',            '🐍', 'OOP, Libraries, Syntax',          2),
  ('Web Dev',           '🌐', 'HTML, CSS, HTTP, APIs',           3),
  ('General Knowledge', '🌍', 'Science, History, Geography',     4),
  ('Data Science',      '📊', 'ML, Pandas, Neural Nets',         5),
  ('Cybersecurity',     '🔐', 'Security Concepts & Attacks',     6);

-- ══════════════════════════════════════════════════════════════
--  SEED: questions — JavaScript
-- ══════════════════════════════════════════════════════════════
INSERT INTO questions (topic_id, question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
SELECT t.id,
       q.question, q.opt_a, q.opt_b, q.opt_c, q.opt_d, q.correct_index, q.difficulty
FROM topics t,
  (VALUES
    ('Which keyword declares a block-scoped variable in JavaScript?',
     'var','let','def','dim', 1, 'easy'),
    ('What does === check in JavaScript?',
     'Value only','Type only','Value and type','Assignment', 2, 'easy'),
    ('Which method adds an element to the end of an array?',
     'unshift','push','append','add', 1, 'easy'),
    ('What is the output of typeof null?',
     'null','undefined','object','boolean', 2, 'medium'),
    ('Which of these is NOT a JavaScript data type?',
     'Symbol','BigInt','Float','undefined', 2, 'medium'),
    ('What does the map() method return?',
     'Original array','New array','Boolean','Undefined', 1, 'easy'),
    ('What is a closure in JavaScript?',
     'A loop construct','A function with access to its outer scope','A built-in method','An ES6 feature', 1, 'medium'),
    ('Which keyword is used to create a class in JavaScript?',
     'function','object','class','define', 2, 'easy'),
    ('What is the purpose of Promise.all()?',
     'Runs promises one by one','Waits for all promises to resolve','Catches promise errors','Cancels promises', 1, 'medium'),
    ('Which operator is used for optional chaining?',
     '??','||','?.','&&', 2, 'medium'),
    ('What does async/await do?',
     'Creates timers','Simplifies promise-based async code','Blocks the event loop','Runs code in a worker', 1, 'medium'),
    ('What is the spread operator?',
     'A multiplication operator','... to expand iterables','A rest parameter','A ternary shorthand', 1, 'easy'),
    ('What does JSON.stringify() do?',
     'Parses JSON','Converts object to JSON string','Formats output','Validates JSON', 1, 'easy'),
    ('Which array method returns the first matching element?',
     'filter','find','map','reduce', 1, 'easy'),
    ('What is event delegation?',
     'Removing event listeners','Attaching one listener to a parent element','Triggering events manually','Cloning events', 1, 'medium'),
    ('What is the difference between null and undefined?',
     'They are the same','null is assigned; undefined is uninitialized','undefined is assigned intentionally','null is a function', 1, 'medium'),
    ('How do you prevent default form submission in JS?',
     'return true','event.prevent()','event.preventDefault()','stopSubmit()', 2, 'easy'),
    ('What does the reduce() method do?',
     'Filters an array','Reduces array to a single value','Removes duplicates','Sorts an array', 1, 'medium'),
    ('What is a prototype in JavaScript?',
     'A blueprint class','An object from which others inherit properties','A type annotation','A module', 1, 'hard'),
    ('Which method converts a string to an array?',
     'split()','slice()','join()','parse()', 0, 'easy')
  ) AS q(question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
WHERE t.key = 'JavaScript';

-- ══════════════════════════════════════════════════════════════
--  SEED: questions — Python
-- ══════════════════════════════════════════════════════════════
INSERT INTO questions (topic_id, question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
SELECT t.id,
       q.question, q.opt_a, q.opt_b, q.opt_c, q.opt_d, q.correct_index, q.difficulty
FROM topics t,
  (VALUES
    ('What keyword defines a function in Python?',
     'function','def','fun','func', 1, 'easy'),
    ('Which of these is a mutable data structure?',
     'tuple','string','list','frozenset', 2, 'easy'),
    ('What does len() return for a string?',
     'Word count','Character count','Byte size','Index position', 1, 'easy'),
    ('What is the output of 3 ** 2?',
     '6','9','8','12', 1, 'easy'),
    ('Which module is used for regular expressions in Python?',
     'regex','re','regexp','match', 1, 'easy'),
    ('How do you open a file for reading in Python?',
     'open(file,"w")','open(file,"r")','file.read()','read(file)', 1, 'easy'),
    ('What does // do in Python?',
     'Float division','Floor division','Bitwise OR','Comment', 1, 'easy'),
    ('Which Python structure stores key-value pairs?',
     'list','tuple','set','dict', 3, 'easy'),
    ('What does range(5) generate?',
     '1 to 5','0 to 5','0 to 4','1 to 4', 2, 'easy'),
    ('What is a decorator in Python?',
     'A CSS concept','A function that wraps another function','A class variable','An import statement', 1, 'medium'),
    ('What does self refer to in a Python class?',
     'The class itself','The current instance','A static method','A global variable', 1, 'medium'),
    ('Which method removes whitespace from both ends of a string?',
     'strip()','clean()','trim()','remove()', 0, 'easy'),
    ('What is list comprehension?',
     'Compressing a list','A concise way to create lists','A sorting method','A filter function', 1, 'medium'),
    ('What does the pass statement do?',
     'Exits a loop','Does nothing; placeholder','Raises an exception','Skips an iteration', 1, 'easy'),
    ('What is the GIL in Python?',
     'Global Index List','Global Interpreter Lock','Graphical Interface Layer','General Input Library', 1, 'hard'),
    ('Which library is used for data manipulation in Python?',
     'NumPy','Pandas','Matplotlib','SciPy', 1, 'easy'),
    ('What does __init__ do?',
     'Destroys an object','Initializes a new instance','Calls a parent class','Imports a module', 1, 'easy'),
    ('What is the difference between is and ==?',
     'No difference','is checks identity; == checks value','== checks identity','is checks value only', 1, 'medium'),
    ('What does enumerate() return?',
     'Just the values','Tuples of (index, value)','Only indexes','A reversed list', 1, 'medium'),
    ('What is *args used for?',
     'Keyword arguments','Variable positional arguments','Unpacking dicts','Static typing', 1, 'medium')
  ) AS q(question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
WHERE t.key = 'Python';

-- ══════════════════════════════════════════════════════════════
--  SEED: questions — Web Dev
-- ══════════════════════════════════════════════════════════════
INSERT INTO questions (topic_id, question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
SELECT t.id,
       q.question, q.opt_a, q.opt_b, q.opt_c, q.opt_d, q.correct_index, q.difficulty
FROM topics t,
  (VALUES
    ('What does HTML stand for?',
     'Hyper Transfer Markup Language','HyperText Markup Language','HyperText Modular Language','High-level Text Markup Language', 1, 'easy'),
    ('Which CSS property controls text size?',
     'font-weight','text-size','font-size','size', 2, 'easy'),
    ('What HTTP method is used to retrieve data?',
     'POST','DELETE','GET','PATCH', 2, 'easy'),
    ('What does CSS flexbox allow?',
     'Animations only','1D layout control','3D transforms','Database queries', 1, 'easy'),
    ('What is a REST API?',
     'A database type','An architectural style for HTTP APIs','A front-end framework','A caching method', 1, 'medium'),
    ('What does the <meta viewport> tag do?',
     'Sets page title','Controls layout on mobile devices','Adds favicons','Defines encoding', 1, 'easy'),
    ('What is CORS?',
     'A CSS reset','Cross-Origin Resource Sharing policy','A compression format','A routing protocol', 1, 'medium'),
    ('Which HTTP status code means Not Found?',
     '200','301','500','404', 3, 'easy'),
    ('What is a semantic HTML element?',
     'An element with no meaning','An element that describes its content','A style-only element','A script tag', 1, 'easy'),
    ('What does CSS Grid provide?',
     '1D layouts','3D animations','2D layout control','Database grids', 2, 'easy'),
    ('What is the purpose of a CDN?',
     'Compile code','Deliver assets from geographically distributed servers','Manage databases','Send emails', 1, 'medium'),
    ('What does localStorage store?',
     'Server-side sessions','Key-value pairs in the browser','Cookies only','SQL data', 1, 'easy'),
    ('What is WebSocket used for?',
     'File uploads','Real-time bi-directional communication','Static file serving','Image compression', 1, 'medium'),
    ('What does box-model refer to in CSS?',
     'Border radius','Content + padding + border + margin','Grid system','Z-index stacking', 1, 'medium'),
    ('What is lazy loading?',
     'Slow websites','Deferring loading of non-critical assets','Caching databases','A JS framework feature', 1, 'medium'),
    ('Which tag is used for semantic navigation?',
     '<div>','<nav>','<span>','<section>', 1, 'easy'),
    ('What does JSON stand for?',
     'JavaScript Object Notation','Java Synchronized Object Node','JSON Syntax Object Node','JavaScript Online Network', 0, 'easy'),
    ('What is the purpose of <alt> in an image tag?',
     'Image title','URL fallback','Accessibility description','Lazy load trigger', 2, 'easy'),
    ('What is a PWA?',
     'Private Web App','Progressive Web App','Parallel Web API','Proxy Web Architecture', 1, 'medium'),
    ('What HTTP method fully updates a resource?',
     'PATCH','POST','PUT','DELETE', 2, 'easy')
  ) AS q(question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
WHERE t.key = 'Web Dev';

-- ══════════════════════════════════════════════════════════════
--  SEED: questions — General Knowledge
-- ══════════════════════════════════════════════════════════════
INSERT INTO questions (topic_id, question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
SELECT t.id,
       q.question, q.opt_a, q.opt_b, q.opt_c, q.opt_d, q.correct_index, q.difficulty
FROM topics t,
  (VALUES
    ('What is the chemical symbol for water?',
     'WA','H2O','HO','OHH', 1, 'easy'),
    ('Which planet is known as the Red Planet?',
     'Venus','Jupiter','Mars','Saturn', 2, 'easy'),
    ('Who wrote Romeo and Juliet?',
     'Charles Dickens','William Shakespeare','Leo Tolstoy','Homer', 1, 'easy'),
    ('What is the capital of France?',
     'London','Berlin','Paris','Madrid', 2, 'easy'),
    ('How many continents are there?',
     '5','6','7','8', 2, 'easy'),
    ('What is the largest ocean?',
     'Atlantic','Indian','Arctic','Pacific', 3, 'easy'),
    ('Which element has atomic number 1?',
     'Helium','Oxygen','Hydrogen','Carbon', 2, 'easy'),
    ('In what year did World War II end?',
     '1942','1943','1944','1945', 3, 'easy'),
    ('What is the speed of light (approx.)?',
     '100,000 km/s','300,000 km/s','500,000 km/s','1,000,000 km/s', 1, 'medium'),
    ('Who painted the Mona Lisa?',
     'Michelangelo','Leonardo da Vinci','Raphael','Vincent van Gogh', 1, 'easy'),
    ('What is the longest river in the world?',
     'Amazon','Yangtze','Nile','Mississippi', 2, 'medium'),
    ('How many bones are in the adult human body?',
     '196','206','216','226', 1, 'medium'),
    ('What gas makes up most of Earth''s atmosphere?',
     'Oxygen','Carbon dioxide','Nitrogen','Argon', 2, 'medium'),
    ('Who was the first person on the Moon?',
     'Buzz Aldrin','Yuri Gagarin','Neil Armstrong','John Glenn', 2, 'easy'),
    ('What is the smallest country by area?',
     'Monaco','San Marino','Vatican City','Liechtenstein', 2, 'medium'),
    ('What is the hardest natural substance?',
     'Gold','Iron','Diamond','Quartz', 2, 'easy'),
    ('Which organ produces insulin?',
     'Liver','Kidney','Heart','Pancreas', 3, 'medium'),
    ('What is the currency of Japan?',
     'Yuan','Won','Yen','Ringgit', 2, 'easy'),
    ('Who developed the theory of relativity?',
     'Newton','Darwin','Einstein','Bohr', 2, 'easy'),
    ('What is the capital of Australia?',
     'Sydney','Melbourne','Canberra','Brisbane', 2, 'medium')
  ) AS q(question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
WHERE t.key = 'General Knowledge';

-- ══════════════════════════════════════════════════════════════
--  SEED: questions — Data Science
-- ══════════════════════════════════════════════════════════════
INSERT INTO questions (topic_id, question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
SELECT t.id,
       q.question, q.opt_a, q.opt_b, q.opt_c, q.opt_d, q.correct_index, q.difficulty
FROM topics t,
  (VALUES
    ('What does ML stand for?',
     'Machine Language','Machine Learning','Multi-Layer','Mathematical Logic', 1, 'easy'),
    ('Which Python library is used for data frames?',
     'NumPy','Pandas','Matplotlib','Seaborn', 1, 'easy'),
    ('What is overfitting?',
     'When a model performs poorly','When a model memorizes training data too well','A data cleaning issue','A GPU error', 1, 'medium'),
    ('What is a neural network?',
     'A brain scan tool','A computing system inspired by biological neurons','A database structure','A Python package', 1, 'medium'),
    ('What does supervised learning require?',
     'Unlabeled data','Labeled training data','Reinforcement signals','No data at all', 1, 'medium'),
    ('What is gradient descent?',
     'A data visualization','An optimization algorithm to minimize loss','A clustering method','A activation function', 1, 'hard'),
    ('What does PCA stand for?',
     'Principal Component Analysis','Predictive Cluster Algorithm','Probabilistic Cluster Approach','Parameter Correction Agent', 0, 'medium'),
    ('What is a confusion matrix used for?',
     'Neural networks','Evaluating classification performance','Feature selection','Data augmentation', 1, 'medium'),
    ('What is a hyperparameter?',
     'A model output','A configuration set before training','A training feature','A dataset label', 1, 'medium'),
    ('What is K-means used for?',
     'Classification','Regression','Clustering','Dimensionality reduction', 2, 'medium'),
    ('What is the purpose of train-test split?',
     'Speed up training','Evaluate model on unseen data','Reduce overfitting only','Normalize data', 1, 'easy'),
    ('What is NLP?',
     'Network Layer Protocol','Natural Language Processing','Neural Learning Procedure','Numeric Layer Propagation', 1, 'easy'),
    ('What is a decision tree?',
     'A data structure','A flowchart-like ML model for decisions','A graph algorithm','A neural layer', 1, 'medium'),
    ('What does dropout do in neural networks?',
     'Removes neurons permanently','Randomly ignores neurons during training to reduce overfitting','Increases model size','Normalizes weights', 1, 'hard'),
    ('What is precision in classification?',
     'TP / (TP + FN)','TP / (TP + FP)','FP / (FP + TN)','TN / (TN + FP)', 1, 'hard'),
    ('What is a random forest?',
     'A single decision tree','An ensemble of decision trees','A clustering method','A deep learning model', 1, 'medium'),
    ('What is feature engineering?',
     'Building hardware for ML','Creating new input features from raw data','Optimizing GPU settings','Selecting a model', 1, 'medium'),
    ('What does RMSE measure?',
     'Classification accuracy','Root Mean Squared Error — regression error','Recall score','Data variance', 1, 'medium'),
    ('What is backpropagation?',
     'Feeding data forward','Algorithm to compute gradients in neural networks','A database rollback','A clustering step', 1, 'hard'),
    ('What is transfer learning?',
     'Copying a dataset','Using a pretrained model for a new task','Sharing weights across GPUs','An ensemble method', 1, 'hard')
  ) AS q(question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
WHERE t.key = 'Data Science';

-- ══════════════════════════════════════════════════════════════
--  SEED: questions — Cybersecurity
-- ══════════════════════════════════════════════════════════════
INSERT INTO questions (topic_id, question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
SELECT t.id,
       q.question, q.opt_a, q.opt_b, q.opt_c, q.opt_d, q.correct_index, q.difficulty
FROM topics t,
  (VALUES
    ('What is phishing?',
     'A fishing game','Deceiving users into revealing credentials via fake communications','Network scanning','A SQL injection', 1, 'easy'),
    ('What does VPN stand for?',
     'Virtual Private Node','Virtual Protocol Network','Virtual Private Network','Verified Proxy Node', 2, 'easy'),
    ('What is a firewall?',
     'A type of virus','A network security system that monitors traffic','A backup system','An encryption protocol', 1, 'easy'),
    ('What does SQL injection exploit?',
     'Weak passwords','Unsanitized database inputs','Open ports','SSL certificates', 1, 'medium'),
    ('What is malware?',
     'Outdated software','Software designed to harm systems','A firewall setting','A backup file', 1, 'easy'),
    ('What is a zero-day vulnerability?',
     'An old bug','Unknown vulnerability with no patch yet','A patched flaw','A firewall rule', 1, 'hard'),
    ('What does HTTPS use to secure data?',
     'FTP','TLS/SSL encryption','VPN tunnels','Password hashing', 1, 'easy'),
    ('What is social engineering?',
     'Building social apps','Manipulating people to reveal sensitive information','Network design','Coding practice', 1, 'medium'),
    ('What is a DDoS attack?',
     'Data deletion','Overwhelming a server with traffic from multiple sources','Database corruption','DNS hijacking', 1, 'medium'),
    ('What is encryption?',
     'Deleting data','Converting data to unreadable format','Compressing files','Copying data', 1, 'easy'),
    ('What is a honeypot in cybersecurity?',
     'A malware type','A decoy system to detect attackers','A password vault','A firewall rule', 1, 'medium'),
    ('What is multifactor authentication (MFA)?',
     'Multiple passwords','Using 2+ verification factors','Biometric only','Email verification', 1, 'easy'),
    ('What does CSRF stand for?',
     'Cross-Site Resource Failure','Cross-Site Request Forgery','Client-Server Request Form','Content Script Request Filter', 1, 'medium'),
    ('What is a brute force attack?',
     'Physical server damage','Trying all possible passwords systematically','Phishing attempt','Virus injection', 1, 'easy'),
    ('What is endpoint security?',
     'Protecting server endpoints','Securing devices like laptops and phones','Network firewall','Email filtering', 1, 'medium'),
    ('What is public key cryptography?',
     'Using one shared key','Using a public and private key pair','Password hashing','VPN tunneling', 1, 'medium'),
    ('What is penetration testing?',
     'Testing server load','Authorized simulated cyberattack to find vulnerabilities','Encrypting data','Patching software', 1, 'medium'),
    ('What does a keylogger do?',
     'Encrypts keystrokes','Records keystrokes to steal data','Blocks keyboard input','Backs up input', 1, 'medium'),
    ('What is the principle of least privilege?',
     'Give all users admin rights','Grant only the minimum access needed','Share passwords securely','Log all user actions', 1, 'medium'),
    ('What is a man-in-the-middle attack?',
     'Installing malware locally','Intercepting communication between two parties','Flooding a server','Deleting system files', 1, 'hard')
  ) AS q(question, opt_a, opt_b, opt_c, opt_d, correct_index, difficulty)
WHERE t.key = 'Cybersecurity';

-- ══════════════════════════════════════════════════════════════
--  USEFUL VIEWS
-- ══════════════════════════════════════════════════════════════

-- Leaderboard view
CREATE OR REPLACE VIEW v_leaderboard AS
SELECT qs.player_name,
       t.key   AS topic,
       t.icon,
       qs.score_pct,
       qs.grade,
       qs.correct,
       qs.num_questions,
       qs.elapsed_secs,
       qs.completed_at,
       ROW_NUMBER() OVER (PARTITION BY t.key ORDER BY qs.score_pct DESC, qs.elapsed_secs ASC) AS rank_in_topic
FROM quiz_sessions qs
JOIN topics t ON t.id = qs.topic_id
WHERE qs.completed_at IS NOT NULL;

-- Topic stats view
CREATE OR REPLACE VIEW v_topic_stats AS
SELECT t.key AS topic,
       COUNT(DISTINCT qs.id)     AS total_attempts,
       ROUND(AVG(qs.score_pct))  AS avg_score,
       MAX(qs.score_pct)         AS top_score,
       COUNT(q.id)               AS question_count
FROM topics t
LEFT JOIN quiz_sessions qs ON qs.topic_id = t.id AND qs.completed_at IS NOT NULL
LEFT JOIN questions q      ON q.topic_id  = t.id
GROUP BY t.key;

-- ══════════════════════════════════════════════════════════════
--  SAMPLE QUERIES (for reference)
-- ══════════════════════════════════════════════════════════════
/*
-- Top 10 leaderboard for JavaScript
SELECT * FROM v_leaderboard WHERE topic = 'JavaScript' AND rank_in_topic <= 10;

-- Topic stats
SELECT * FROM v_topic_stats;

-- Player history
SELECT topic, score_pct, grade, correct, num_questions, elapsed_secs, completed_at
FROM quiz_sessions qs
JOIN topics t ON t.id = qs.topic_id
WHERE LOWER(player_name) = 'john doe' AND completed_at IS NOT NULL
ORDER BY completed_at DESC;
*/
