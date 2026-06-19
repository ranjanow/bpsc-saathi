-- Migration 004: Authentication System
-- Creates users, refresh_tokens, and password_reset_tokens tables.
--
-- Run: psql -U postgres -d bpsc_db -f 004_auth.sql

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Users table
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),              -- NULL for OAuth-only accounts
    full_name VARCHAR(255) NOT NULL,
    avatar_url TEXT DEFAULT '',
    provider VARCHAR(50) DEFAULT 'email',    -- 'email', 'google'
    role VARCHAR(20) DEFAULT 'student',      -- 'student', 'mentor', 'admin'
    is_verified BOOLEAN DEFAULT FALSE,
    total_xp INTEGER DEFAULT 0,
    streak_days INTEGER DEFAULT 0,
    quizzes_taken INTEGER DEFAULT 0,
    accuracy DOUBLE PRECISION DEFAULT 0.0,
    preferred_language VARCHAR(10) DEFAULT 'both',
    theme_mode VARCHAR(20) DEFAULT 'vibrant',
    bio TEXT DEFAULT '',
    target_exam VARCHAR(100) DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_provider ON users(provider);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. Refresh tokens — one user can have multiple active sessions
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    revoked BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_hash ON refresh_tokens(token_hash);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. Password reset tokens — short-lived, single-use
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_user ON password_reset_tokens(user_id);

COMMIT;
