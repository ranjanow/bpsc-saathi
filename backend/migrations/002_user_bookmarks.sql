-- ============================================================
-- Migration: 002_user_bookmarks.sql
-- Project:   BPSC Engine — Examination Intelligence System
-- Purpose:   Introduce the user_bookmarks table so learners
--            can save individual questions for later review.
--
-- Prerequisites:
--   Migration 001_initial_schema.sql must have run first
--   (pgcrypto extension is already enabled there).
--
-- Run with:
--   psql -U postgres -d bpsc_db -f 002_user_bookmarks.sql
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- TABLE: user_bookmarks
--
-- Design notes
-- ────────────
-- • user_id is stored as TEXT rather than a foreign-keyed UUID
--   because the platform's auth layer is decoupled from this DB
--   (user records live in an external identity provider).
--   A VARCHAR(128) cap prevents unbounded inserts while
--   comfortably accommodating UUID v4, Firebase UID, and
--   Supabase Auth UID formats.
--
-- • question_id mirrors the string IDs that the LLM produces
--   (e.g. "q-001").  It is NOT a foreign key to generated_questions
--   because bookmarks can persist even after an ecosystem is
--   soft-deleted; the full question payload is self-contained
--   in the question_data JSONB column.
--
-- • question_data is a JSONB snapshot of the complete question
--   at the time it was bookmarked.  This makes the bookmarks
--   table an independent, append-only audit log: future edits
--   or deletions to generated_questions do NOT corrupt saved
--   review sessions.
--
-- • The UNIQUE (user_id, question_id) constraint enforces one
--   bookmark per user per question at the database level.
--   The Go layer uses ON CONFLICT DO NOTHING so duplicate saves
--   are silently idempotent rather than returning an error.
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_bookmarks (
    -- Surrogate primary key.
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Opaque user identifier supplied by the calling client.
    -- Treated as an opaque token; no FK constraint to an auth table.
    user_id         VARCHAR(128) NOT NULL,

    -- The question identifier (e.g. "q-001") as returned by the LLM.
    question_id     VARCHAR(64)  NOT NULL,

    -- The top-level subject/concept tag for the bookmarked question
    -- (e.g. "History", "Polity").  Denormalised here for fast
    -- server-side filtering without having to parse the JSONB blob.
    concept_tag     VARCHAR(128) NOT NULL DEFAULT '',

    -- Full question snapshot — stores the complete GeneratedQuestion
    -- struct (text, options, correct index, explanation, difficulty,
    -- subject) serialised as JSONB.
    -- Using JSONB (not JSON) gives us compressed binary storage,
    -- GIN-index support, and @> containment queries if needed later.
    question_data   JSONB        NOT NULL DEFAULT '{}',

    -- Wall-clock time when the bookmark was created.
    -- TIMESTAMPTZ preserves timezone info for multi-region deployments.
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    -- ── Constraints ──────────────────────────────────────────────
    -- One bookmark per (user, question) pair — prevents duplicates
    -- even under concurrent requests from the same user.
    CONSTRAINT uq_user_question UNIQUE (user_id, question_id)
);

-- ──────────────────────────────────────────────────────────────
-- INDEXES
-- ──────────────────────────────────────────────────────────────

-- Primary access pattern: fetch all bookmarks for a given user.
-- This index covers the GetByUserID query entirely (index-only scan
-- is possible when combined with the covering columns).
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id
    ON user_bookmarks (user_id, created_at DESC);

-- Secondary pattern: check/delete a specific (user, question) pair.
-- The UNIQUE constraint above already creates a B-tree index on
-- (user_id, question_id), so an explicit index here would be redundant.
-- The constraint index is used automatically by the DELETE query.

-- Optional: GIN index for full JSONB containment queries (e.g. find
-- all bookmarks where question_data @> '{"difficulty":"hard"}').
-- Commented out by default — uncomment if analytics queries are needed.
-- CREATE INDEX IF NOT EXISTS idx_bookmarks_question_data_gin
--     ON user_bookmarks USING GIN (question_data);


-- ──────────────────────────────────────────────────────────────
-- Rollback helper (comment out when running forward migration)
-- ──────────────────────────────────────────────────────────────
-- DROP TABLE IF EXISTS user_bookmarks;
