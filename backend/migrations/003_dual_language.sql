-- ============================================================
-- Migration: 003_dual_language.sql
-- Project:   BPSC Engine
-- Purpose:   Add dual language support (EN/HI) to questions.
-- ============================================================

ALTER TABLE generated_questions
    RENAME COLUMN question_text TO question_en;

ALTER TABLE generated_questions
    RENAME COLUMN options TO options_en;

ALTER TABLE generated_questions
    RENAME COLUMN explanation TO explanation_en;

ALTER TABLE generated_questions
    ADD COLUMN question_hi TEXT NOT NULL DEFAULT '',
    ADD COLUMN options_hi JSONB NOT NULL DEFAULT '[]',
    ADD COLUMN explanation_hi TEXT NOT NULL DEFAULT '';
