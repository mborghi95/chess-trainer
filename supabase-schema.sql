-- Chess Trainer — Supabase Schema
-- Run this in: Supabase Dashboard → SQL Editor → New query

-- ── opening_plays ─────────────────────────────────────────────────────────────
-- Tracks how many times each opening has been started and completed per user.

CREATE TABLE IF NOT EXISTS opening_plays (
    id               BIGSERIAL PRIMARY KEY,
    user_id          UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    opening_id       TEXT        NOT NULL,   -- e.g. "london-white"
    opening_name     TEXT        NOT NULL,   -- e.g. "London System"
    play_count       INTEGER     NOT NULL DEFAULT 0,
    completion_count INTEGER     NOT NULL DEFAULT 0,
    last_played_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, opening_id)
);

-- Index for fast per-user lookups
CREATE INDEX IF NOT EXISTS opening_plays_user_idx ON opening_plays (user_id);

-- Row Level Security: users can only see and write their own rows
ALTER TABLE opening_plays ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own opening_plays"
    ON opening_plays FOR ALL
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


-- ── mistakes ──────────────────────────────────────────────────────────────────
-- Tracks every wrong move made, grouped by opening + move index.

CREATE TABLE IF NOT EXISTS mistakes (
    id           BIGSERIAL PRIMARY KEY,
    user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    opening_id   TEXT        NOT NULL,   -- e.g. "london-white"
    opening_name TEXT        NOT NULL,   -- e.g. "London System"
    move_index   INTEGER     NOT NULL,   -- 0-based index into the opening's moves array
    move_san     TEXT        NOT NULL,   -- the correct SAN that was missed, e.g. "Bf4"
    count        INTEGER     NOT NULL DEFAULT 0,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, opening_id, move_index)
);

-- Index for fast per-user lookups
CREATE INDEX IF NOT EXISTS mistakes_user_idx ON mistakes (user_id);

-- Row Level Security: users can only see and write their own rows
ALTER TABLE mistakes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own mistakes"
    ON mistakes FOR ALL
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
