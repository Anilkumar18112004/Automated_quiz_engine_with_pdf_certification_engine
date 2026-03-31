# QuizMaster Pro — Full Stack Setup

## Project Structure
```
quizmaster-pro/
├── frontend/
│   └── QuizApp.jsx        ← React component
├── backend/
│   └── server.js          ← Express API
├── database/
│   └── schema.sql         ← PostgreSQL schema + seed data
└── README.md
```

---

## 1. Database (PostgreSQL)

```bash
# Create the database
createdb quizmaster

# Run the schema (creates tables + seeds 120 questions)
psql -d quizmaster -f database/schema.sql
```

---

## 2. Backend (Node.js + Express)

```bash
cd backend
npm install express cors pg dotenv
```

Create a `.env` file:
```
PORT=4000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=quizmaster
DB_USER=postgres
DB_PASSWORD=yourpassword
FRONTEND_URL=http://localhost:5173
```

Start the server:
```bash
node server.js
# ✅ QuizMaster API running at http://localhost:4000
```

### API Endpoints
| Method | Route | Description |
|--------|-------|-------------|
| GET | /api/health | Liveness check |
| GET | /api/topics | All topics with question count |
| GET | /api/questions/:topicKey | All questions for a topic |
| POST | /api/quiz/start | Create session, get shuffled questions |
| POST | /api/quiz/submit | Save answers, compute score |
| GET | /api/leaderboard?topic=X | Top 10 scores |
| GET | /api/history/:playerName | Player's past sessions |

---

## 3. Frontend (React + Vite)

```bash
cd frontend
npm create vite@latest . -- --template react
npm install
```

Add `QuizApp.jsx` to `src/`, then update `src/main.jsx`:
```jsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import QuizApp from './QuizApp'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(<QuizApp />)
```

Add jsPDF to `index.html` (inside `<head>`):
```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
```

Create `.env`:
```
VITE_API_URL=http://localhost:4000/api
```

Copy the CSS from your original `quiz_engine.html` into `src/index.css`.

Start the dev server:
```bash
npm run dev
# Running at http://localhost:5173
```

---

## Architecture Overview

```
Browser (React)
    │  GET /api/topics
    │  POST /api/quiz/start  →  returns sessionId + questions
    │  POST /api/quiz/submit →  saves answers, returns score
    ▼
Express Server (Node.js :4000)
    │
    ▼
PostgreSQL
  ├── topics          (6 rows)
  ├── questions       (120 rows, 20 per topic)
  ├── quiz_sessions   (one row per attempt)
  └── quiz_answers    (one row per answer)
```
