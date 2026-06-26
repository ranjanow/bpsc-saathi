package repositories

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"
)

// ─────────────────────────────────────────────────────────────────────────────
// FeaturesRepository — consolidated repo for Features 3–9
// Quiz Caching, Chat, Revision, Mock Tests, Study Planner, Bookmarks v2
// ─────────────────────────────────────────────────────────────────────────────

type FeaturesRepository struct {
	db *sql.DB
}

func NewFeaturesRepository(db *sql.DB) *FeaturesRepository {
	return &FeaturesRepository{db: db}
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE 3: Daily Quiz Caching
// ═══════════════════════════════════════════════════════════════════════════

type CachedQuiz struct {
	ID            string          `json:"id"`
	QuizDate      string          `json:"quizDate"`
	QuestionsJSON json.RawMessage `json:"questions"`
	QuestionCount int             `json:"questionCount"`
	GeneratedAt   time.Time       `json:"generatedAt"`
}

func (r *FeaturesRepository) GetTodayQuiz() (*CachedQuiz, error) {
	today := time.Now().Format("2006-01-02")
	var quiz CachedQuiz
	err := r.db.QueryRow(
		`SELECT id, quiz_date::TEXT, questions_json, question_count, generated_at
		 FROM daily_quizzes WHERE quiz_date = $1`, today,
	).Scan(&quiz.ID, &quiz.QuizDate, &quiz.QuestionsJSON, &quiz.QuestionCount, &quiz.GeneratedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("GetTodayQuiz: %w", err)
	}
	return &quiz, nil
}

func (r *FeaturesRepository) CacheQuiz(questionsJSON []byte) (*CachedQuiz, error) {
	today := time.Now().Format("2006-01-02")
	var quiz CachedQuiz
	err := r.db.QueryRow(
		`INSERT INTO daily_quizzes (quiz_date, questions_json, question_count)
		 VALUES ($1, $2, 15)
		 ON CONFLICT (quiz_date) DO UPDATE SET questions_json = $2
		 RETURNING id, quiz_date::TEXT, questions_json, question_count, generated_at`,
		today, questionsJSON,
	).Scan(&quiz.ID, &quiz.QuizDate, &quiz.QuestionsJSON, &quiz.QuestionCount, &quiz.GeneratedAt)

	if err != nil {
		return nil, fmt.Errorf("CacheQuiz: %w", err)
	}
	log.Printf("[QuizCache] ✅ Cached quiz for %s", today)
	return &quiz, nil
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE 4 & 5: Chat Sessions (Tutor + Mentor)
// ═══════════════════════════════════════════════════════════════════════════

type ChatSession struct {
	ID          string    `json:"id"`
	UserID      string    `json:"userId"`
	SessionType string    `json:"sessionType"`
	Title       string    `json:"title"`
	IsActive    bool      `json:"isActive"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

type ChatMessage struct {
	ID        string          `json:"id"`
	SessionID string          `json:"sessionId"`
	Role      string          `json:"role"`
	Content   string          `json:"content"`
	Metadata  json.RawMessage `json:"metadata,omitempty"`
	CreatedAt time.Time       `json:"createdAt"`
}

func (r *FeaturesRepository) CreateChatSession(userID, sessionType, title string) (*ChatSession, error) {
	var s ChatSession
	err := r.db.QueryRow(
		`INSERT INTO chat_sessions (user_id, session_type, title) VALUES ($1, $2, $3)
		 RETURNING id, user_id, session_type, title, is_active, created_at, updated_at`,
		userID, sessionType, title,
	).Scan(&s.ID, &s.UserID, &s.SessionType, &s.Title, &s.IsActive, &s.CreatedAt, &s.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("CreateChatSession: %w", err)
	}
	return &s, nil
}

func (r *FeaturesRepository) GetUserChatSessions(userID string, limit int) ([]ChatSession, error) {
	if limit <= 0 {
		limit = 20
	}
	rows, err := r.db.Query(
		`SELECT id, user_id, session_type, title, is_active, created_at, updated_at
		 FROM chat_sessions WHERE user_id = $1 AND is_active = TRUE ORDER BY updated_at DESC LIMIT $2`,
		userID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []ChatSession
	for rows.Next() {
		var s ChatSession
		if err := rows.Scan(&s.ID, &s.UserID, &s.SessionType, &s.Title, &s.IsActive, &s.CreatedAt, &s.UpdatedAt); err != nil {
			continue
		}
		sessions = append(sessions, s)
	}
	return sessions, nil
}

func (r *FeaturesRepository) AddChatMessage(sessionID, role, content string, metadata []byte) (*ChatMessage, error) {
	if metadata == nil {
		metadata = []byte("{}")
	}
	var m ChatMessage
	err := r.db.QueryRow(
		`INSERT INTO chat_messages (session_id, role, content, metadata) VALUES ($1, $2, $3, $4)
		 RETURNING id, session_id, role, content, metadata, created_at`,
		sessionID, role, content, metadata,
	).Scan(&m.ID, &m.SessionID, &m.Role, &m.Content, &m.Metadata, &m.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("AddChatMessage: %w", err)
	}

	// Update session timestamp
	_, _ = r.db.Exec(`UPDATE chat_sessions SET updated_at = NOW() WHERE id = $1`, sessionID)
	return &m, nil
}

func (r *FeaturesRepository) GetChatMessages(sessionID string, limit int) ([]ChatMessage, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := r.db.Query(
		`SELECT id, session_id, role, content, metadata, created_at
		 FROM chat_messages WHERE session_id = $1 ORDER BY created_at ASC LIMIT $2`,
		sessionID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []ChatMessage
	for rows.Next() {
		var m ChatMessage
		if err := rows.Scan(&m.ID, &m.SessionID, &m.Role, &m.Content, &m.Metadata, &m.CreatedAt); err != nil {
			continue
		}
		messages = append(messages, m)
	}
	return messages, nil
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE 6: Revision Engine (SM-2 Algorithm)
// ═══════════════════════════════════════════════════════════════════════════

type RevisionItem struct {
	ID             string     `json:"id"`
	UserID         string     `json:"userId"`
	Subject        string     `json:"subject"`
	Topic          string     `json:"topic"`
	Difficulty     string     `json:"difficulty"`
	EaseFactor     float64    `json:"easeFactor"`
	IntervalDays   int        `json:"intervalDays"`
	Repetitions    int        `json:"repetitions"`
	NextReviewAt   time.Time  `json:"nextReviewAt"`
	LastReviewedAt *time.Time `json:"lastReviewedAt"`
}

func (r *FeaturesRepository) GetTodayRevisions(userID string) ([]RevisionItem, error) {
	rows, err := r.db.Query(
		`SELECT id, user_id, subject, topic, difficulty, ease_factor, interval_days, repetitions, next_review_at, last_reviewed_at
		 FROM revision_queue WHERE user_id = $1 AND next_review_at <= NOW() ORDER BY next_review_at ASC LIMIT 20`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []RevisionItem
	for rows.Next() {
		var item RevisionItem
		if err := rows.Scan(&item.ID, &item.UserID, &item.Subject, &item.Topic, &item.Difficulty,
			&item.EaseFactor, &item.IntervalDays, &item.Repetitions, &item.NextReviewAt, &item.LastReviewedAt); err != nil {
			continue
		}
		items = append(items, item)
	}
	return items, nil
}

func (r *FeaturesRepository) AddToRevisionQueue(userID, subject, topic, difficulty string) error {
	_, err := r.db.Exec(
		`INSERT INTO revision_queue (user_id, subject, topic, difficulty)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (user_id, subject, topic) DO NOTHING`,
		userID, subject, topic, difficulty,
	)
	return err
}

// CompleteRevision implements SM-2 algorithm update
func (r *FeaturesRepository) CompleteRevision(itemID string, quality int) error {
	// quality: 0-5 (0=blackout, 5=perfect)
	var easeFactor float64
	var interval int
	var repetitions int

	err := r.db.QueryRow(
		`SELECT ease_factor, interval_days, repetitions FROM revision_queue WHERE id = $1`,
		itemID,
	).Scan(&easeFactor, &interval, &repetitions)
	if err != nil {
		return fmt.Errorf("CompleteRevision: %w", err)
	}

	// SM-2 Algorithm
	if quality < 3 {
		repetitions = 0
		interval = 1
	} else {
		if repetitions == 0 {
			interval = 1
		} else if repetitions == 1 {
			interval = 6
		} else {
			interval = int(float64(interval) * easeFactor)
		}
		repetitions++
	}

	easeFactor = easeFactor + (0.1 - float64(5-quality)*(0.08+float64(5-quality)*0.02))
	if easeFactor < 1.3 {
		easeFactor = 1.3
	}

	nextReview := time.Now().AddDate(0, 0, interval)

	_, err = r.db.Exec(
		`UPDATE revision_queue SET ease_factor = $1, interval_days = $2, repetitions = $3,
		 next_review_at = $4, last_reviewed_at = NOW() WHERE id = $5`,
		easeFactor, interval, repetitions, nextReview, itemID,
	)
	return err
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE 7: Mock Tests
// ═══════════════════════════════════════════════════════════════════════════

type MockTest struct {
	ID              string          `json:"id"`
	Title           string          `json:"title"`
	Description     string          `json:"description"`
	QuestionCount   int             `json:"questionCount"`
	DurationMinutes int             `json:"durationMinutes"`
	NegativeMarking float64         `json:"negativeMarking"`
	QuestionsJSON   json.RawMessage `json:"questions,omitempty"`
	IsActive        bool            `json:"isActive"`
	CreatedAt       time.Time       `json:"createdAt"`
}

type MockAttempt struct {
	ID                   string          `json:"id"`
	UserID               string          `json:"userId"`
	MockTestID           string          `json:"mockTestId"`
	Status               string          `json:"status"`
	AnswersJSON          json.RawMessage `json:"answers"`
	CurrentQuestion      int             `json:"currentQuestion"`
	TimeRemainingSeconds *int            `json:"timeRemainingSeconds"`
	StartedAt            time.Time       `json:"startedAt"`
}

type MockResult struct {
	ID               string          `json:"id"`
	AttemptID        string          `json:"attemptId"`
	TotalQuestions   int             `json:"totalQuestions"`
	Attempted        int             `json:"attempted"`
	Correct          int             `json:"correct"`
	Incorrect        int             `json:"incorrect"`
	Unattempted      int             `json:"unattempted"`
	RawScore         float64         `json:"rawScore"`
	Percentage       float64         `json:"percentage"`
	Rank             *int            `json:"rank"`
	Percentile       *float64        `json:"percentile"`
	SubjectBreakdown json.RawMessage `json:"subjectBreakdown"`
}

func (r *FeaturesRepository) GetMockTests() ([]MockTest, error) {
	rows, err := r.db.Query(
		`SELECT id, title, description, question_count, duration_minutes, negative_marking, is_active, created_at
		 FROM mock_tests WHERE is_active = TRUE ORDER BY created_at DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tests []MockTest
	for rows.Next() {
		var t MockTest
		if err := rows.Scan(&t.ID, &t.Title, &t.Description, &t.QuestionCount, &t.DurationMinutes,
			&t.NegativeMarking, &t.IsActive, &t.CreatedAt); err != nil {
			continue
		}
		tests = append(tests, t)
	}
	return tests, nil
}

func (r *FeaturesRepository) GetMockTest(id string) (*MockTest, error) {
	var t MockTest
	err := r.db.QueryRow(
		`SELECT id, title, description, question_count, duration_minutes, negative_marking, questions_json, is_active, created_at
		 FROM mock_tests WHERE id = $1`, id,
	).Scan(&t.ID, &t.Title, &t.Description, &t.QuestionCount, &t.DurationMinutes,
		&t.NegativeMarking, &t.QuestionsJSON, &t.IsActive, &t.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (r *FeaturesRepository) StartMockAttempt(userID, mockTestID string, timeSeconds int) (*MockAttempt, error) {
	var a MockAttempt
	err := r.db.QueryRow(
		`INSERT INTO mock_attempts (user_id, mock_test_id, time_remaining_seconds, answers_json)
		 VALUES ($1, $2, $3, '{}')
		 RETURNING id, user_id, mock_test_id, status, answers_json, current_question, time_remaining_seconds, started_at`,
		userID, mockTestID, timeSeconds,
	).Scan(&a.ID, &a.UserID, &a.MockTestID, &a.Status, &a.AnswersJSON, &a.CurrentQuestion, &a.TimeRemainingSeconds, &a.StartedAt)
	if err != nil {
		return nil, fmt.Errorf("StartMockAttempt: %w", err)
	}
	return &a, nil
}

func (r *FeaturesRepository) SubmitMockTest(attemptID string, answers json.RawMessage, result *MockResult) error {
	_, err := r.db.Exec(
		`UPDATE mock_attempts SET status = 'completed', answers_json = $1, completed_at = NOW() WHERE id = $2`,
		answers, attemptID,
	)
	if err != nil {
		return err
	}

	_, err = r.db.Exec(
		`INSERT INTO mock_results (attempt_id, user_id, total_questions, attempted, correct, incorrect, unattempted, raw_score, percentage, subject_breakdown)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		attemptID, result.AttemptID, result.TotalQuestions, result.Attempted, result.Correct,
		result.Incorrect, result.Unattempted, result.RawScore, result.Percentage, result.SubjectBreakdown,
	)
	return err
}

func (r *FeaturesRepository) GetMockResult(attemptID string) (*MockResult, error) {
	var res MockResult
	err := r.db.QueryRow(
		`SELECT id, attempt_id, total_questions, attempted, correct, incorrect, unattempted,
		        raw_score, percentage, rank, percentile, subject_breakdown
		 FROM mock_results WHERE attempt_id = $1`, attemptID,
	).Scan(&res.ID, &res.AttemptID, &res.TotalQuestions, &res.Attempted, &res.Correct,
		&res.Incorrect, &res.Unattempted, &res.RawScore, &res.Percentage,
		&res.Rank, &res.Percentile, &res.SubjectBreakdown)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &res, nil
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE 8: Study Planner
// ═══════════════════════════════════════════════════════════════════════════

type StudyPlan struct {
	ID               string          `json:"id"`
	UserID           string          `json:"userId"`
	ExamDate         *string         `json:"examDate"`
	TargetHoursPerDay float64        `json:"targetHoursPerDay"`
	SubjectsJSON     json.RawMessage `json:"subjects"`
	IsActive         bool            `json:"isActive"`
	CreatedAt        time.Time       `json:"createdAt"`
}

type StudyTask struct {
	ID              string     `json:"id"`
	PlanID          string     `json:"planId"`
	UserID          string     `json:"userId"`
	Subject         string     `json:"subject"`
	Topic           string     `json:"topic"`
	TaskType        string     `json:"taskType"`
	ScheduledDate   string     `json:"scheduledDate"`
	DurationMinutes int        `json:"durationMinutes"`
	IsCompleted     bool       `json:"isCompleted"`
	CompletedAt     *time.Time `json:"completedAt"`
}

func (r *FeaturesRepository) CreateStudyPlan(userID string, examDate *string, targetHours float64, subjects []byte) (*StudyPlan, error) {
	// Deactivate existing plans
	_, _ = r.db.Exec(`UPDATE study_plans SET is_active = FALSE WHERE user_id = $1`, userID)

	var plan StudyPlan
	err := r.db.QueryRow(
		`INSERT INTO study_plans (user_id, exam_date, target_hours_per_day, subjects_json)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, user_id, exam_date::TEXT, target_hours_per_day, subjects_json, is_active, created_at`,
		userID, examDate, targetHours, subjects,
	).Scan(&plan.ID, &plan.UserID, &plan.ExamDate, &plan.TargetHoursPerDay, &plan.SubjectsJSON, &plan.IsActive, &plan.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &plan, nil
}

func (r *FeaturesRepository) GetActivePlan(userID string) (*StudyPlan, error) {
	var plan StudyPlan
	err := r.db.QueryRow(
		`SELECT id, user_id, exam_date::TEXT, target_hours_per_day, subjects_json, is_active, created_at
		 FROM study_plans WHERE user_id = $1 AND is_active = TRUE ORDER BY created_at DESC LIMIT 1`, userID,
	).Scan(&plan.ID, &plan.UserID, &plan.ExamDate, &plan.TargetHoursPerDay, &plan.SubjectsJSON, &plan.IsActive, &plan.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &plan, nil
}

func (r *FeaturesRepository) GetTodayTasks(userID string) ([]StudyTask, error) {
	today := time.Now().Format("2006-01-02")
	rows, err := r.db.Query(
		`SELECT id, plan_id, user_id, subject, topic, task_type, scheduled_date::TEXT, duration_minutes, is_completed, completed_at
		 FROM study_tasks WHERE user_id = $1 AND scheduled_date = $2 ORDER BY created_at`,
		userID, today,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tasks []StudyTask
	for rows.Next() {
		var t StudyTask
		if err := rows.Scan(&t.ID, &t.PlanID, &t.UserID, &t.Subject, &t.Topic, &t.TaskType,
			&t.ScheduledDate, &t.DurationMinutes, &t.IsCompleted, &t.CompletedAt); err != nil {
			continue
		}
		tasks = append(tasks, t)
	}
	return tasks, nil
}

func (r *FeaturesRepository) CompleteTask(taskID, userID string) error {
	_, err := r.db.Exec(
		`UPDATE study_tasks SET is_completed = TRUE, completed_at = NOW() WHERE id = $1 AND user_id = $2`,
		taskID, userID,
	)
	return err
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE 9: Saved Notes (Bookmarks v2)
// ═══════════════════════════════════════════════════════════════════════════

type SavedNote struct {
	ID        string    `json:"id"`
	UserID    string    `json:"userId"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	NoteType  string    `json:"noteType"`
	Subject   string    `json:"subject"`
	Topic     string    `json:"topic"`
	SourceID  string    `json:"sourceId"`
	Tags      json.RawMessage `json:"tags"`
	CreatedAt time.Time `json:"createdAt"`
}

func (r *FeaturesRepository) CreateNote(userID, title, content, noteType, subject, topic, sourceID string, tags []byte) (*SavedNote, error) {
	if tags == nil {
		tags = []byte("[]")
	}
	var note SavedNote
	err := r.db.QueryRow(
		`INSERT INTO saved_notes (user_id, title, content, note_type, subject, topic, source_id, tags)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		 RETURNING id, user_id, title, content, note_type, COALESCE(subject,''), COALESCE(topic,''), COALESCE(source_id,''), tags, created_at`,
		userID, title, content, noteType, subject, topic, sourceID, tags,
	).Scan(&note.ID, &note.UserID, &note.Title, &note.Content, &note.NoteType,
		&note.Subject, &note.Topic, &note.SourceID, &note.Tags, &note.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &note, nil
}

func (r *FeaturesRepository) GetNotes(userID string, limit int) ([]SavedNote, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := r.db.Query(
		`SELECT id, user_id, title, content, note_type, COALESCE(subject,''), COALESCE(topic,''), COALESCE(source_id,''), tags, created_at
		 FROM saved_notes WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
		userID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notes []SavedNote
	for rows.Next() {
		var n SavedNote
		if err := rows.Scan(&n.ID, &n.UserID, &n.Title, &n.Content, &n.NoteType,
			&n.Subject, &n.Topic, &n.SourceID, &n.Tags, &n.CreatedAt); err != nil {
			continue
		}
		notes = append(notes, n)
	}
	return notes, nil
}

func (r *FeaturesRepository) DeleteNote(noteID, userID string) error {
	_, err := r.db.Exec(`DELETE FROM saved_notes WHERE id = $1 AND user_id = $2`, noteID, userID)
	return err
}

// ═══════════════════════════════════════════════════════════════════════════
// Migration — create all Feature 3–9 tables
// ═══════════════════════════════════════════════════════════════════════════

func (r *FeaturesRepository) RunMigration() error {
	queries := []string{
		// F3: Quiz caching
		`CREATE TABLE IF NOT EXISTS daily_quizzes (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), quiz_date DATE UNIQUE NOT NULL,
			questions_json JSONB NOT NULL, question_count INTEGER NOT NULL DEFAULT 15, generated_at TIMESTAMPTZ DEFAULT NOW())`,
		`CREATE TABLE IF NOT EXISTS daily_quiz_attempts (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			quiz_id UUID NOT NULL REFERENCES daily_quizzes(id) ON DELETE CASCADE, score INTEGER NOT NULL, total INTEGER NOT NULL,
			answers_json JSONB DEFAULT '{}', completed_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(user_id, quiz_id))`,
		// F4/F5: Chat
		`CREATE TABLE IF NOT EXISTS chat_sessions (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			session_type VARCHAR(50) DEFAULT 'tutor', title VARCHAR(255) DEFAULT 'New Chat',
			is_active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW())`,
		`CREATE TABLE IF NOT EXISTS chat_messages (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), session_id UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
			role VARCHAR(20) NOT NULL, content TEXT NOT NULL, metadata JSONB DEFAULT '{}', created_at TIMESTAMPTZ DEFAULT NOW())`,
		// F6: Revision
		`CREATE TABLE IF NOT EXISTS revision_queue (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			subject VARCHAR(100) NOT NULL, topic VARCHAR(255) NOT NULL, difficulty VARCHAR(20) DEFAULT 'medium',
			ease_factor DOUBLE PRECISION DEFAULT 2.5, interval_days INTEGER DEFAULT 1, repetitions INTEGER DEFAULT 0,
			next_review_at TIMESTAMPTZ DEFAULT NOW(), last_reviewed_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT NOW(),
			UNIQUE(user_id, subject, topic))`,
		`CREATE TABLE IF NOT EXISTS weak_topics (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			subject VARCHAR(100) NOT NULL, topic VARCHAR(255) NOT NULL, error_count INTEGER DEFAULT 0,
			total_attempts INTEGER DEFAULT 0, weakness_score DOUBLE PRECISION DEFAULT 0.0,
			detected_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(user_id, subject, topic))`,
		// F7: Mock tests
		`CREATE TABLE IF NOT EXISTS mock_tests (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), title VARCHAR(255) NOT NULL, description TEXT DEFAULT '',
			question_count INTEGER NOT NULL DEFAULT 150, duration_minutes INTEGER NOT NULL DEFAULT 120,
			negative_marking DOUBLE PRECISION DEFAULT 0.33, questions_json JSONB NOT NULL,
			is_active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW())`,
		`CREATE TABLE IF NOT EXISTS mock_attempts (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			mock_test_id UUID NOT NULL REFERENCES mock_tests(id) ON DELETE CASCADE,
			status VARCHAR(20) DEFAULT 'in_progress', answers_json JSONB DEFAULT '{}', current_question INTEGER DEFAULT 0,
			time_remaining_seconds INTEGER, started_at TIMESTAMPTZ DEFAULT NOW(), paused_at TIMESTAMPTZ, completed_at TIMESTAMPTZ)`,
		`CREATE TABLE IF NOT EXISTS mock_results (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), attempt_id UUID NOT NULL REFERENCES mock_attempts(id) ON DELETE CASCADE,
			user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, total_questions INTEGER NOT NULL,
			attempted INTEGER NOT NULL, correct INTEGER NOT NULL, incorrect INTEGER NOT NULL, unattempted INTEGER NOT NULL,
			raw_score DOUBLE PRECISION NOT NULL, percentage DOUBLE PRECISION NOT NULL, rank INTEGER, percentile DOUBLE PRECISION,
			subject_breakdown JSONB DEFAULT '{}', created_at TIMESTAMPTZ DEFAULT NOW())`,
		// F8: Study planner
		`CREATE TABLE IF NOT EXISTS study_plans (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			exam_date DATE, target_hours_per_day DOUBLE PRECISION DEFAULT 4.0, subjects_json JSONB DEFAULT '[]',
			is_active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW())`,
		`CREATE TABLE IF NOT EXISTS study_tasks (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), plan_id UUID NOT NULL REFERENCES study_plans(id) ON DELETE CASCADE,
			user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, subject VARCHAR(100) NOT NULL, topic VARCHAR(255) NOT NULL,
			task_type VARCHAR(50) DEFAULT 'study', scheduled_date DATE NOT NULL, duration_minutes INTEGER DEFAULT 60,
			is_completed BOOLEAN DEFAULT FALSE, completed_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT NOW())`,
		// F9: Saved notes
		`CREATE TABLE IF NOT EXISTS saved_notes (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			title VARCHAR(255) NOT NULL, content TEXT NOT NULL, note_type VARCHAR(50) DEFAULT 'note',
			subject VARCHAR(100), topic VARCHAR(255), source_id VARCHAR(255), tags JSONB DEFAULT '[]',
			created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW())`,
	}

	for _, q := range queries {
		if _, err := r.db.Exec(q); err != nil {
			return fmt.Errorf("FeaturesMigration: %w", err)
		}
	}
	log.Println("[Features] ✅ Migration complete — F3-F9 tables ready")
	return nil
}
