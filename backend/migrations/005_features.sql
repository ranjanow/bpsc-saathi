-- Migration 005: Features 2–9 Tables
-- Analytics, Quiz Caching, AI Tutor, Revision, Mock Tests, Study Planner, Bookmarks v2

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- FEATURE 2: User Analytics
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS user_quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quiz_type VARCHAR(50) NOT NULL,          -- 'daily', 'prelims', 'mock'
    subject VARCHAR(100),
    total_questions INTEGER NOT NULL,
    correct_answers INTEGER NOT NULL,
    accuracy DOUBLE PRECISION NOT NULL,
    time_spent_seconds INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user ON user_quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_date ON user_quiz_attempts(created_at);

CREATE TABLE IF NOT EXISTS study_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(100),
    duration_minutes INTEGER NOT NULL,
    session_type VARCHAR(50) DEFAULT 'study', -- 'study', 'revision', 'quiz', 'tutor'
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_study_sessions_user ON study_sessions(user_id);

CREATE TABLE IF NOT EXISTS user_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL,      -- 'quiz', 'study', 'tutor', 'revision'
    activity_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_activity_user ON user_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_date ON user_activity(created_at);

CREATE TABLE IF NOT EXISTS subject_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(100) NOT NULL,
    total_questions INTEGER DEFAULT 0,
    correct_answers INTEGER DEFAULT 0,
    accuracy DOUBLE PRECISION DEFAULT 0.0,
    mastery_level VARCHAR(20) DEFAULT 'beginner', -- beginner, intermediate, advanced, expert
    last_studied_at TIMESTAMPTZ,
    UNIQUE(user_id, subject)
);
CREATE INDEX IF NOT EXISTS idx_subject_progress_user ON subject_progress(user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- FEATURE 3: Daily Quiz Caching
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS daily_quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_date DATE UNIQUE NOT NULL,
    questions_json JSONB NOT NULL,
    question_count INTEGER NOT NULL DEFAULT 15,
    generated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_daily_quizzes_date ON daily_quizzes(quiz_date);

CREATE TABLE IF NOT EXISTS daily_quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quiz_id UUID NOT NULL REFERENCES daily_quizzes(id) ON DELETE CASCADE,
    score INTEGER NOT NULL,
    total INTEGER NOT NULL,
    answers_json JSONB DEFAULT '{}',
    completed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, quiz_id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- FEATURE 4 & 5: AI Tutor + Mentor Chat
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_type VARCHAR(50) DEFAULT 'tutor',  -- 'tutor', 'mentor', 'pyq_explain'
    title VARCHAR(255) DEFAULT 'New Chat',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user ON chat_sessions(user_id);

CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL,                  -- 'user', 'assistant'
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',                -- subject, topic, pyq_year etc.
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- FEATURE 6: Smart Revision Engine
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS revision_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(100) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    difficulty VARCHAR(20) DEFAULT 'medium',
    ease_factor DOUBLE PRECISION DEFAULT 2.5,   -- SM-2 ease factor
    interval_days INTEGER DEFAULT 1,            -- current interval
    repetitions INTEGER DEFAULT 0,
    next_review_at TIMESTAMPTZ DEFAULT NOW(),
    last_reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, subject, topic)
);
CREATE INDEX IF NOT EXISTS idx_revision_queue_user ON revision_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_revision_queue_next ON revision_queue(next_review_at);

CREATE TABLE IF NOT EXISTS weak_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(100) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    error_count INTEGER DEFAULT 0,
    total_attempts INTEGER DEFAULT 0,
    weakness_score DOUBLE PRECISION DEFAULT 0.0,
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, subject, topic)
);
CREATE INDEX IF NOT EXISTS idx_weak_topics_user ON weak_topics(user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- FEATURE 7: Mock Test Engine
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS mock_tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    question_count INTEGER NOT NULL DEFAULT 150,
    duration_minutes INTEGER NOT NULL DEFAULT 120,
    negative_marking DOUBLE PRECISION DEFAULT 0.33,
    questions_json JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS mock_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mock_test_id UUID NOT NULL REFERENCES mock_tests(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'in_progress',   -- 'in_progress', 'paused', 'completed', 'auto_submitted'
    answers_json JSONB DEFAULT '{}',
    current_question INTEGER DEFAULT 0,
    time_remaining_seconds INTEGER,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    paused_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_mock_attempts_user ON mock_attempts(user_id);

CREATE TABLE IF NOT EXISTS mock_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attempt_id UUID NOT NULL REFERENCES mock_attempts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_questions INTEGER NOT NULL,
    attempted INTEGER NOT NULL,
    correct INTEGER NOT NULL,
    incorrect INTEGER NOT NULL,
    unattempted INTEGER NOT NULL,
    raw_score DOUBLE PRECISION NOT NULL,
    percentage DOUBLE PRECISION NOT NULL,
    rank INTEGER,
    percentile DOUBLE PRECISION,
    subject_breakdown JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_mock_results_user ON mock_results(user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- FEATURE 8: Study Planner
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS study_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exam_date DATE,
    target_hours_per_day DOUBLE PRECISION DEFAULT 4.0,
    subjects_json JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_study_plans_user ON study_plans(user_id);

CREATE TABLE IF NOT EXISTS study_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL REFERENCES study_plans(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(100) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    task_type VARCHAR(50) DEFAULT 'study',       -- 'study', 'revision', 'quiz', 'mock'
    scheduled_date DATE NOT NULL,
    duration_minutes INTEGER DEFAULT 60,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_study_tasks_user ON study_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_study_tasks_date ON study_tasks(scheduled_date);

-- ═══════════════════════════════════════════════════════════════════════════
-- FEATURE 9: Bookmarks v2 (extend existing user_bookmarks)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS saved_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    note_type VARCHAR(50) DEFAULT 'note',        -- 'note', 'ai_explanation', 'chat_save', 'pyq_note'
    subject VARCHAR(100),
    topic VARCHAR(255),
    source_id VARCHAR(255),                      -- reference to chat message or question ID
    tags JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_saved_notes_user ON saved_notes(user_id);

COMMIT;
