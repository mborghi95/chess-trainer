# CLAUDE.md — Chess Opening Trainer

This file gives Claude Code the context it needs to work on this project without re-discovering things each session.

---

## Project purpose

A single-page chess opening trainer for a ~700 ELO player (Matt). The app teaches openings move by move, gives AI coaching via Claude, lets users free-play against Stockfish, drill their most-missed positions, and review real games they've played.

---

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Vanilla JS, jQuery 3.7.1, no build system |
| Chess logic | chess.js 0.10.3 (move validation, PGN parsing, FEN) |
| Board rendering | chessboard.js 1.0.0 |
| Chess engine | Stockfish.js 10.0.2 (loaded via CDN into a Web Worker on demand) |
| AI coach | Claude Haiku via Anthropic API, proxied through a Vercel serverless function |
| Auth | Supabase Auth (email + password) |
| Database | Supabase Postgres (two tables: `opening_plays`, `mistakes`) |
| Hosting | Vercel (auto-deploys from GitHub `main` branch) |
| All CDN libs | Loaded via `<script>` tags — no npm, no bundler |

---

## File structure

```
chess-trainer/
├── index.html              # The entire app — HTML, CSS, and JS in one file
├── api/
│   └── chat.js             # Vercel serverless function — proxies requests to Anthropic API
│                           # Keeps ANTHROPIC_API_KEY server-side only
├── supabase-schema.sql     # Run this in Supabase SQL Editor to create the DB tables
├── SUPABASE_SETUP.md       # 4-step guide for wiring up a Supabase project
└── CLAUDE.md               # This file
```

Everything lives in `index.html`. Do not introduce a build system, separate JS files, or npm packages.

---

## index.html structure (in order)

1. **`<head>` / `<style>`** — CSS variables, layout, board, chat, auth modals, stats modal, review modal
2. **HTML body** — Header (opening selector + auth + review game button), board section (controls, free-play bar, review drill bar, status, move log), chat section, modals (auth, stats, review game)
3. **CDN `<script>` tags** — jQuery, chess.js, chessboard.js, Supabase JS v2
4. **`<script>` block** — All application JavaScript, in sections:
   - `SUPABASE CONFIG` — credentials + `initSupabase()`, auth state, `supabaseClient`
   - `AUTH UI` — `openAuthModal`, `closeAuthModal`, `switchAuthTab`, `submitAuth`, `signOut`, `updateAuthUI`
   - `DATA MIGRATION` — `doMigrate`, `skipMigrate`, `migrateLocalStorageToSupabase`
   - `SUPABASE SYNC` — `syncOpeningToSupabase`, `syncMistakeToSupabase`
   - `STATS MODAL` — `openStatsModal`, `closeStatsModal`, `renderStats`
   - `OPENING DATA` — `const OPENINGS = { ... }` — all hardcoded opening lines
   - `GAME STATE` — global variables
   - `BOARD SIZING` — responsive board width
   - `BOARD INIT` — `initBoard`, click-to-move, drag events
   - `OPENING LOGIC` — `loadOpening`, `playOpponentMove`, `completeOpening`
   - `HINT` — `showHint`, `clearHints`, `clearSelection`, `onSquareClick`
   - `UI HELPERS` — `setStatus`, `updateProgress`, `updateMoveLog`
   - `CLAUDE CHAT` — `sendMessage`, `addChat`, `toggleChat`
   - `SPACED REPETITION` — `loadStats`, `saveStats`, `recordSessionStart`, `recordError`, `recordCompletion`, `getWeakMoveIndices`, `updateWeakSpotsIndicator`, `drillWeakMoves`
   - `FREE PLAY vs STOCKFISH` — `initStockfish`, `handleStockfishMessage`, `setSkillLevel`, `askStockfish`, `applyStockfishMove`, `onDropFreePlay`, `enterFreePlay`, `exitFreePlay`
   - `REVIEW A GAME` — `openReviewModal`, `analyseGame`, `detectPlayerColor`, `fetchGameAnalysis`, `renderReviewResults`, `drillFromMove`, `exitReviewDrill`
   - `BOOT` — `$(document).ready(...)` — calls `loadStats`, `initBoard`, `initSupabase`

---

## Openings data model

```js
OPENINGS['london-white'] = {
  id: 'london-white',
  name: 'London System',
  playerColor: 'w',          // 'w' or 'b'
  description: '...',
  moves: [
    {
      san: 'd4',
      color: 'w',            // whose move
      comment: '...',        // shown in move log
      sidelines: [           // optional — moves that are wrong but educational
        { san: 'e3', feedback: "Don't play e3 before Bf4!..." }
      ]
    },
    // ...
  ]
}
```

Currently 16 openings (London, Caro-Kann, King's Indian, Ruy Lopez, Italian, Sicilian, French, Queen's Gambit — both colors each).

---

## Spaced repetition system

Stored in `localStorage` under key `chessTrainerStats`, and synced to Supabase when signed in.

```js
stats = {
  'london-white': {
    sessions:    5,       // times loadOpening() called
    completions: 3,       // times line completed
    lastPlayed:  1712000000000,  // timestamp ms
    moveErrors: {
      '4': 2,   // moveIdx 4 (0-based into opening.moves[]) missed 2 times
      '8': 1
    }
  }
}
```

Key functions:
- `recordSessionStart(openingId)` — increments sessions, syncs to Supabase
- `recordError(openingId, moveIndex)` — increments moveErrors, syncs to Supabase
- `recordCompletion(openingId)` — increments completions, syncs to Supabase
- `drillWeakMoves()` — replays moves silently up to the earliest error move, lets user practice from there
- `updateWeakSpotsIndicator()` — shows/hides the "N weak spots" badge above the board

---

## Supabase schema

Two tables, both with Row Level Security enabled (users only see their own rows):

**`opening_plays`** — `(user_id, opening_id, opening_name, play_count, completion_count, last_played_at)`
- Unique constraint on `(user_id, opening_id)`
- Upserted on every `recordSessionStart` and `recordCompletion`

**`mistakes`** — `(user_id, opening_id, opening_name, move_index, move_san, count, last_seen_at)`
- Unique constraint on `(user_id, opening_id, move_index)`
- Upserted on every `recordError`

Supabase credentials are hardcoded in `index.html` (anon key only — safe to expose).

---

## API proxy (`api/chat.js`)

All Claude API calls go through this Vercel serverless function to keep `ANTHROPIC_API_KEY` out of the browser.

- Endpoint: `POST /api/chat`
- Accepts: `{ model, max_tokens, system, messages }`
- Forwards to: `https://api.anthropic.com/v1/messages`
- Used by: AI coach chat (`sendMessage`) and game analysis (`fetchGameAnalysis`)
- Model used: `claude-haiku-4-5-20251001` (fast and cheap for coaching/analysis)

---

## Review a Game feature

Users paste a PGN from chess.com or lichess. The flow:

1. `analyseGame()` — parses PGN with `chess.js`, builds a `reviewFENs[]` array (one FEN per half-move)
2. `detectPlayerColor()` — tries to match Supabase email username against PGN White/Black headers; shows a color picker if ambiguous
3. `fetchGameAnalysis()` — sends PGN to `/api/chat` with a structured prompt asking Claude for 3–5 key moments as JSON
4. `renderReviewResults()` — shows analysis summary card + full annotated move list
5. `drillFromMove(halfMoveIndex)` — sets `game = new Chess(fen)`, enters free-play mode against Stockfish from that position
6. `exitReviewDrill()` — returns to normal trainer UI, re-opens the analysis modal

`reviewFENs[0]` = starting position, `reviewFENs[N]` = position after the Nth half-move (1-based).

---

## Deployment

- **GitHub repo:** `mborghi95/chess-trainer` (public)
- **Vercel project:** `chess-trainer` under team `matts-projects-edf50af8`
- **Auto-deploy:** any push to `main` triggers a Vercel production deployment
- **Env var:** `ANTHROPIC_API_KEY` set in Vercel project settings (not in repo)

---

## Key constraints

- **No build system** — everything must stay in `index.html` + the `api/` folder
- **No npm packages** — use CDN script tags only
- **Supabase anon key** is safe to include in source (enforced by RLS policies)
- **Keep the app functional when signed out** — localStorage is always the source of truth; Supabase is additive
- **Mobile-first** — the board and controls must work on small screens; use the existing responsive CSS patterns
