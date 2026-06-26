package repositories

import (
	"database/sql"
	"fmt"
	"log"
	"time"
)

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsRepository — tracks user quiz attempts, study sessions, activity
// ─────────────────────────────────────────────────────────────────────────────

type AnalyticsRepository struct {
	db *sql.DB
}

func NewAnalyticsRepository(db *sql.DB) *AnalyticsRepository {
	return &AnalyticsRepository{db: db}
}

// ── Quiz Attempt Tracking ─────────────────────────────────────────────────

type QuizAttempt struct {
	ID               string    `json:"id"`
	UserID           string    `json:"userId"`
	QuizType         string    `json:"quizType"`
	Subject          string    `json:"subject"`
	TotalQuestions   int       `json:"totalQuestions"`
	CorrectAnswers   int       `json:"correctAnswers"`
	Accuracy         float64   `json:"accuracy"`
	TimeSpentSeconds int       `json:"timeSpentSeconds"`
	CreatedAt        time.Time `json:"createdAt"`
}

func (r *AnalyticsRepository) RecordQuizAttempt(userID, quizType, subject string, total, correct, timeSec int) error {
	accuracy := 0.0
	if total > 0 {
		accuracy = float64(correct) / float64(total) * 100
	}
	_, err := r.db.Exec(
		`INSERT INTO user_quiz_attempts (user_id, quiz_type, subject, total_questions, correct_answers, accuracy, time_spent_seconds)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		userID, quizType, subject, total, correct, accuracy, timeSec,
	)
	if err != nil {
		return fmt.Errorf("RecordQuizAttempt: %w", err)
	}

	// Update user stats
	_, _ = r.db.Exec(`UPDATE users SET quizzes_taken = quizzes_taken + 1, updated_at = NOW() WHERE id = $1`, userID)

	// Update subject progress
	_, _ = r.db.Exec(
		`INSERT INTO subject_progress (user_id, subject, total_questions, correct_answers, accuracy, last_studied_at)
		 VALUES ($1, $2, $3, $4, $5, NOW())
		 ON CONFLICT (user_id, subject) DO UPDATE SET
		   total_questions = subject_progress.total_questions + $3,
		   correct_answers = subject_progress.correct_answers + $4,
		   accuracy = CASE WHEN (subject_progress.total_questions + $3) > 0
		     THEN (subject_progress.correct_answers + $4)::float / (subject_progress.total_questions + $3) * 100
		     ELSE 0 END,
		   last_studied_at = NOW()`,
		userID, subject, total, correct, accuracy,
	)

	return nil
}

func (r *AnalyticsRepository) GetQuizHistory(userID string, limit int) ([]QuizAttempt, error) {
	if limit <= 0 {
		limit = 20
	}
	rows, err := r.db.Query(
		`SELECT id, user_id, quiz_type, COALESCE(subject,''), total_questions, correct_answers, accuracy, time_spent_seconds, created_at
		 FROM user_quiz_attempts WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
		userID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("GetQuizHistory: %w", err)
	}
	defer rows.Close()

	var attempts []QuizAttempt
	for rows.Next() {
		var a QuizAttempt
		if err := rows.Scan(&a.ID, &a.UserID, &a.QuizType, &a.Subject, &a.TotalQuestions, &a.CorrectAnswers, &a.Accuracy, &a.TimeSpentSeconds, &a.CreatedAt); err != nil {
			continue
		}
		attempts = append(attempts, a)
	}
	return attempts, nil
}

// ── Study Sessions ────────────────────────────────────────────────────────

func (r *AnalyticsRepository) RecordStudySession(userID, subject, sessionType string, durationMin int) error {
	_, err := r.db.Exec(
		`INSERT INTO study_sessions (user_id, subject, duration_minutes, session_type)
		 VALUES ($1, $2, $3, $4)`,
		userID, subject, durationMin, sessionType,
	)
	return err
}

func (r *AnalyticsRepository) GetTotalStudyHours(userID string) (float64, error) {
	var totalMin sql.NullFloat64
	err := r.db.QueryRow(
		`SELECT SUM(duration_minutes) FROM study_sessions WHERE user_id = $1`, userID,
	).Scan(&totalMin)
	if err != nil {
		return 0, err
	}
	if !totalMin.Valid {
		return 0, nil
	}
	return totalMin.Float64 / 60.0, nil
}

// ── Streak Calculation ────────────────────────────────────────────────────

type StreakInfo struct {
	CurrentStreak int    `json:"currentStreak"`
	BestStreak    int    `json:"bestStreak"`
	LastActive    string `json:"lastActive"`
}

func (r *AnalyticsRepository) GetStreak(userID string) (*StreakInfo, error) {
	rows, err := r.db.Query(
		`SELECT DISTINCT DATE(created_at) as d FROM user_activity
		 WHERE user_id = $1 ORDER BY d DESC LIMIT 365`, userID,
	)
	if err != nil {
		return &StreakInfo{}, err
	}
	defer rows.Close()

	var dates []time.Time
	for rows.Next() {
		var d time.Time
		if err := rows.Scan(&d); err != nil {
			continue
		}
		dates = append(dates, d)
	}

	if len(dates) == 0 {
		return &StreakInfo{CurrentStreak: 0, BestStreak: 0, LastActive: ""}, nil
	}

	// Calculate current streak
	today := time.Now().Truncate(24 * time.Hour)
	current := 0
	best := 0
	streak := 0

	for i, d := range dates {
		expected := today.AddDate(0, 0, -i)
		if d.Truncate(24*time.Hour).Equal(expected) {
			streak++
		} else {
			break
		}
	}
	current = streak

	// Calculate best streak
	streak = 1
	for i := 1; i < len(dates); i++ {
		diff := dates[i-1].Sub(dates[i]).Hours() / 24
		if diff <= 1.5 {
			streak++
		} else {
			if streak > best {
				best = streak
			}
			streak = 1
		}
	}
	if streak > best {
		best = streak
	}
	if current > best {
		best = current
	}

	return &StreakInfo{
		CurrentStreak: current,
		BestStreak:    best,
		LastActive:    dates[0].Format("2006-01-02"),
	}, nil
}

// ── Subject Mastery ───────────────────────────────────────────────────────

type SubjectMastery struct {
	Subject       string  `json:"subject"`
	TotalQ        int     `json:"totalQuestions"`
	CorrectQ      int     `json:"correctAnswers"`
	Accuracy      float64 `json:"accuracy"`
	MasteryLevel  string  `json:"masteryLevel"`
	LastStudiedAt *string `json:"lastStudiedAt"`
}

func (r *AnalyticsRepository) GetSubjectMastery(userID string) ([]SubjectMastery, error) {
	rows, err := r.db.Query(
		`SELECT subject, total_questions, correct_answers, accuracy, mastery_level,
		        TO_CHAR(last_studied_at, 'YYYY-MM-DD')
		 FROM subject_progress WHERE user_id = $1 ORDER BY accuracy DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []SubjectMastery
	for rows.Next() {
		var s SubjectMastery
		var lastStudied sql.NullString
		if err := rows.Scan(&s.Subject, &s.TotalQ, &s.CorrectQ, &s.Accuracy, &s.MasteryLevel, &lastStudied); err != nil {
			continue
		}
		if lastStudied.Valid {
			s.LastStudiedAt = &lastStudied.String
		}
		result = append(result, s)
	}
	return result, nil
}

// ── Weekly Activity Heatmap ───────────────────────────────────────────────

type DayActivity struct {
	Date  string `json:"date"`
	Count int    `json:"count"`
}

func (r *AnalyticsRepository) GetWeeklyActivity(userID string, weeks int) ([]DayActivity, error) {
	if weeks <= 0 {
		weeks = 12
	}
	rows, err := r.db.Query(
		`SELECT DATE(created_at) as d, COUNT(*) as c
		 FROM user_activity WHERE user_id = $1 AND created_at >= NOW() - ($2 || ' weeks')::INTERVAL
		 GROUP BY d ORDER BY d`,
		userID, fmt.Sprintf("%d", weeks),
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []DayActivity
	for rows.Next() {
		var d DayActivity
		var date time.Time
		if err := rows.Scan(&date, &d.Count); err != nil {
			continue
		}
		d.Date = date.Format("2006-01-02")
		result = append(result, d)
	}
	return result, nil
}

// ── Dashboard Aggregation ─────────────────────────────────────────────────

type DashboardAnalytics struct {
	TotalStudyHours float64          `json:"totalStudyHours"`
	QuizzesTaken    int              `json:"quizzesTaken"`
	OverallAccuracy float64          `json:"overallAccuracy"`
	Streak          *StreakInfo       `json:"streak"`
	SubjectMastery  []SubjectMastery `json:"subjectMastery"`
	RecentQuizzes   []QuizAttempt    `json:"recentQuizzes"`
	WeeklyActivity  []DayActivity    `json:"weeklyActivity"`
}

func (r *AnalyticsRepository) GetDashboard(userID string) (*DashboardAnalytics, error) {
	dash := &DashboardAnalytics{}

	hours, _ := r.GetTotalStudyHours(userID)
	dash.TotalStudyHours = hours

	// Overall stats
	var quizzes int
	var acc sql.NullFloat64
	_ = r.db.QueryRow(`SELECT COUNT(*), AVG(accuracy) FROM user_quiz_attempts WHERE user_id = $1`, userID).Scan(&quizzes, &acc)
	dash.QuizzesTaken = quizzes
	if acc.Valid {
		dash.OverallAccuracy = acc.Float64
	}

	streak, _ := r.GetStreak(userID)
	dash.Streak = streak

	mastery, _ := r.GetSubjectMastery(userID)
	dash.SubjectMastery = mastery

	recent, _ := r.GetQuizHistory(userID, 10)
	dash.RecentQuizzes = recent

	weekly, _ := r.GetWeeklyActivity(userID, 12)
	dash.WeeklyActivity = weekly

	return dash, nil
}

// ── Record Activity ───────────────────────────────────────────────────────

func (r *AnalyticsRepository) RecordActivity(userID, activityType string) error {
	_, err := r.db.Exec(
		`INSERT INTO user_activity (user_id, activity_type) VALUES ($1, $2)`,
		userID, activityType,
	)
	return err
}

// ── Migration ─────────────────────────────────────────────────────────────

func (r *AnalyticsRepository) RunMigration() error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS user_quiz_attempts (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			quiz_type VARCHAR(50) NOT NULL, subject VARCHAR(100), total_questions INTEGER NOT NULL,
			correct_answers INTEGER NOT NULL, accuracy DOUBLE PRECISION NOT NULL, time_spent_seconds INTEGER DEFAULT 0,
			created_at TIMESTAMPTZ DEFAULT NOW())`,
		`CREATE TABLE IF NOT EXISTS study_sessions (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			subject VARCHAR(100), duration_minutes INTEGER NOT NULL, session_type VARCHAR(50) DEFAULT 'study',
			started_at TIMESTAMPTZ DEFAULT NOW(), ended_at TIMESTAMPTZ)`,
		`CREATE TABLE IF NOT EXISTS user_activity (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			activity_type VARCHAR(50) NOT NULL, activity_data JSONB DEFAULT '{}', created_at TIMESTAMPTZ DEFAULT NOW())`,
		`CREATE TABLE IF NOT EXISTS subject_progress (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			subject VARCHAR(100) NOT NULL, total_questions INTEGER DEFAULT 0, correct_answers INTEGER DEFAULT 0,
			accuracy DOUBLE PRECISION DEFAULT 0.0, mastery_level VARCHAR(20) DEFAULT 'beginner',
			last_studied_at TIMESTAMPTZ, UNIQUE(user_id, subject))`,
	}
	for _, q := range queries {
		if _, err := r.db.Exec(q); err != nil {
			return fmt.Errorf("AnalyticsMigration: %w", err)
		}
	}
	log.Println("[Analytics] ✅ Migration complete")
	return nil
}
