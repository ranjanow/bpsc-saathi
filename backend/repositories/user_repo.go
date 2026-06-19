package repositories

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"bpsc-engine/models"
)

// ─────────────────────────────────────────────────────────────────────────────
// UserRepository — PostgreSQL-backed user + token storage
// ─────────────────────────────────────────────────────────────────────────────

// UserRepository handles all database operations for users and auth tokens.
type UserRepository struct {
	db *sql.DB
}

// NewUserRepository creates a new UserRepository.
func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

// ═══════════════════════════════════════════════════════════════════════════
// User CRUD
// ═══════════════════════════════════════════════════════════════════════════

// CreateUser inserts a new user and returns the populated User.
func (r *UserRepository) CreateUser(user *models.User) (*models.User, error) {
	query := `
		INSERT INTO users (email, password_hash, full_name, avatar_url, provider, role, is_verified)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, email, password_hash, full_name, avatar_url, provider, role, is_verified,
		          total_xp, streak_days, quizzes_taken, accuracy, preferred_language, theme_mode,
		          bio, target_exam, created_at, updated_at, last_login`

	var created models.User
	err := r.db.QueryRow(
		query,
		user.Email,
		user.PasswordHash,
		user.FullName,
		user.AvatarURL,
		user.Provider,
		user.Role,
		user.IsVerified,
	).Scan(
		&created.ID, &created.Email, &created.PasswordHash, &created.FullName,
		&created.AvatarURL, &created.Provider, &created.Role, &created.IsVerified,
		&created.TotalXP, &created.StreakDays, &created.QuizzesTaken, &created.Accuracy,
		&created.PreferredLanguage, &created.ThemeMode, &created.Bio, &created.TargetExam,
		&created.CreatedAt, &created.UpdatedAt, &created.LastLogin,
	)
	if err != nil {
		return nil, fmt.Errorf("CreateUser: %w", err)
	}

	log.Printf("[UserRepo] ✅ Created user id=%s email=%s", created.ID, created.Email)
	return &created, nil
}

// GetUserByEmail retrieves a user by email address.
func (r *UserRepository) GetUserByEmail(email string) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, avatar_url, provider, role, is_verified,
		       total_xp, streak_days, quizzes_taken, accuracy, preferred_language, theme_mode,
		       bio, target_exam, created_at, updated_at, last_login
		FROM users WHERE email = $1`

	var user models.User
	err := r.db.QueryRow(query, email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FullName,
		&user.AvatarURL, &user.Provider, &user.Role, &user.IsVerified,
		&user.TotalXP, &user.StreakDays, &user.QuizzesTaken, &user.Accuracy,
		&user.PreferredLanguage, &user.ThemeMode, &user.Bio, &user.TargetExam,
		&user.CreatedAt, &user.UpdatedAt, &user.LastLogin,
	)
	if err == sql.ErrNoRows {
		return nil, nil // Not found
	}
	if err != nil {
		return nil, fmt.Errorf("GetUserByEmail: %w", err)
	}
	return &user, nil
}

// GetUserByID retrieves a user by UUID.
func (r *UserRepository) GetUserByID(id string) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, avatar_url, provider, role, is_verified,
		       total_xp, streak_days, quizzes_taken, accuracy, preferred_language, theme_mode,
		       bio, target_exam, created_at, updated_at, last_login
		FROM users WHERE id = $1`

	var user models.User
	err := r.db.QueryRow(query, id).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FullName,
		&user.AvatarURL, &user.Provider, &user.Role, &user.IsVerified,
		&user.TotalXP, &user.StreakDays, &user.QuizzesTaken, &user.Accuracy,
		&user.PreferredLanguage, &user.ThemeMode, &user.Bio, &user.TargetExam,
		&user.CreatedAt, &user.UpdatedAt, &user.LastLogin,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("GetUserByID: %w", err)
	}
	return &user, nil
}

// UpdateUser updates mutable profile fields for a user.
func (r *UserRepository) UpdateUser(userID string, req *models.UpdateProfileRequest) (*models.User, error) {
	// Build dynamic SET clause
	setClauses := []string{}
	args := []interface{}{}
	argIdx := 1

	if req.FullName != nil {
		setClauses = append(setClauses, fmt.Sprintf("full_name = $%d", argIdx))
		args = append(args, *req.FullName)
		argIdx++
	}
	if req.Bio != nil {
		setClauses = append(setClauses, fmt.Sprintf("bio = $%d", argIdx))
		args = append(args, *req.Bio)
		argIdx++
	}
	if req.TargetExam != nil {
		setClauses = append(setClauses, fmt.Sprintf("target_exam = $%d", argIdx))
		args = append(args, *req.TargetExam)
		argIdx++
	}
	if req.PreferredLanguage != nil {
		setClauses = append(setClauses, fmt.Sprintf("preferred_language = $%d", argIdx))
		args = append(args, *req.PreferredLanguage)
		argIdx++
	}
	if req.ThemeMode != nil {
		setClauses = append(setClauses, fmt.Sprintf("theme_mode = $%d", argIdx))
		args = append(args, *req.ThemeMode)
		argIdx++
	}
	if req.AvatarURL != nil {
		setClauses = append(setClauses, fmt.Sprintf("avatar_url = $%d", argIdx))
		args = append(args, *req.AvatarURL)
		argIdx++
	}

	if len(setClauses) == 0 {
		return r.GetUserByID(userID)
	}

	// Always update updated_at
	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now())
	argIdx++

	// Add user_id as final arg
	args = append(args, userID)

	query := fmt.Sprintf(`
		UPDATE users SET %s WHERE id = $%d
		RETURNING id, email, password_hash, full_name, avatar_url, provider, role, is_verified,
		          total_xp, streak_days, quizzes_taken, accuracy, preferred_language, theme_mode,
		          bio, target_exam, created_at, updated_at, last_login`,
		joinStrings(setClauses, ", "), argIdx)

	var user models.User
	err := r.db.QueryRow(query, args...).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FullName,
		&user.AvatarURL, &user.Provider, &user.Role, &user.IsVerified,
		&user.TotalXP, &user.StreakDays, &user.QuizzesTaken, &user.Accuracy,
		&user.PreferredLanguage, &user.ThemeMode, &user.Bio, &user.TargetExam,
		&user.CreatedAt, &user.UpdatedAt, &user.LastLogin,
	)
	if err != nil {
		return nil, fmt.Errorf("UpdateUser: %w", err)
	}

	log.Printf("[UserRepo] ✅ Updated user id=%s", userID)
	return &user, nil
}

// UpdateLastLogin sets the last_login timestamp.
func (r *UserRepository) UpdateLastLogin(userID string) error {
	_, err := r.db.Exec(`UPDATE users SET last_login = NOW() WHERE id = $1`, userID)
	if err != nil {
		return fmt.Errorf("UpdateLastLogin: %w", err)
	}
	return nil
}

// UpdatePasswordHash sets a new password hash for the user.
func (r *UserRepository) UpdatePasswordHash(userID, hash string) error {
	_, err := r.db.Exec(
		`UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`,
		hash, userID,
	)
	if err != nil {
		return fmt.Errorf("UpdatePasswordHash: %w", err)
	}
	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// Refresh Tokens
// ═══════════════════════════════════════════════════════════════════════════

// RefreshTokenRecord represents a row in the refresh_tokens table.
type RefreshTokenRecord struct {
	ID        string
	UserID    string
	TokenHash string
	ExpiresAt time.Time
	CreatedAt time.Time
	Revoked   bool
}

// StoreRefreshToken inserts a new refresh token record.
func (r *UserRepository) StoreRefreshToken(userID, tokenHash string, expiresAt time.Time) error {
	_, err := r.db.Exec(
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, tokenHash, expiresAt,
	)
	if err != nil {
		return fmt.Errorf("StoreRefreshToken: %w", err)
	}
	return nil
}

// GetRefreshToken retrieves a refresh token by its hash.
func (r *UserRepository) GetRefreshToken(tokenHash string) (*RefreshTokenRecord, error) {
	query := `SELECT id, user_id, token_hash, expires_at, created_at, revoked
	          FROM refresh_tokens WHERE token_hash = $1`

	var rec RefreshTokenRecord
	err := r.db.QueryRow(query, tokenHash).Scan(
		&rec.ID, &rec.UserID, &rec.TokenHash, &rec.ExpiresAt, &rec.CreatedAt, &rec.Revoked,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("GetRefreshToken: %w", err)
	}
	return &rec, nil
}

// RevokeRefreshToken marks a single refresh token as revoked.
func (r *UserRepository) RevokeRefreshToken(tokenHash string) error {
	_, err := r.db.Exec(`UPDATE refresh_tokens SET revoked = TRUE WHERE token_hash = $1`, tokenHash)
	if err != nil {
		return fmt.Errorf("RevokeRefreshToken: %w", err)
	}
	return nil
}

// RevokeAllUserRefreshTokens revokes all refresh tokens for a user (logout-all).
func (r *UserRepository) RevokeAllUserRefreshTokens(userID string) error {
	_, err := r.db.Exec(`UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = $1`, userID)
	if err != nil {
		return fmt.Errorf("RevokeAllUserRefreshTokens: %w", err)
	}
	return nil
}

// CleanExpiredRefreshTokens removes expired/revoked tokens (housekeeping).
func (r *UserRepository) CleanExpiredRefreshTokens() (int64, error) {
	result, err := r.db.Exec(
		`DELETE FROM refresh_tokens WHERE expires_at < NOW() OR revoked = TRUE`,
	)
	if err != nil {
		return 0, fmt.Errorf("CleanExpiredRefreshTokens: %w", err)
	}
	return result.RowsAffected()
}

// ═══════════════════════════════════════════════════════════════════════════
// Password Reset Tokens
// ═══════════════════════════════════════════════════════════════════════════

// PasswordResetRecord represents a row in the password_reset_tokens table.
type PasswordResetRecord struct {
	ID        string
	UserID    string
	TokenHash string
	ExpiresAt time.Time
	Used      bool
	CreatedAt time.Time
}

// StorePasswordResetToken inserts a new password reset token.
func (r *UserRepository) StorePasswordResetToken(userID, tokenHash string, expiresAt time.Time) error {
	_, err := r.db.Exec(
		`INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, tokenHash, expiresAt,
	)
	if err != nil {
		return fmt.Errorf("StorePasswordResetToken: %w", err)
	}
	return nil
}

// GetPasswordResetToken retrieves a password reset token by its hash.
func (r *UserRepository) GetPasswordResetToken(tokenHash string) (*PasswordResetRecord, error) {
	query := `SELECT id, user_id, token_hash, expires_at, used, created_at
	          FROM password_reset_tokens WHERE token_hash = $1`

	var rec PasswordResetRecord
	err := r.db.QueryRow(query, tokenHash).Scan(
		&rec.ID, &rec.UserID, &rec.TokenHash, &rec.ExpiresAt, &rec.Used, &rec.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("GetPasswordResetToken: %w", err)
	}
	return &rec, nil
}

// MarkPasswordResetTokenUsed marks a password reset token as used.
func (r *UserRepository) MarkPasswordResetTokenUsed(tokenHash string) error {
	_, err := r.db.Exec(
		`UPDATE password_reset_tokens SET used = TRUE WHERE token_hash = $1`,
		tokenHash,
	)
	if err != nil {
		return fmt.Errorf("MarkPasswordResetTokenUsed: %w", err)
	}
	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

// joinStrings joins a slice of strings with a separator.
func joinStrings(strs []string, sep string) string {
	result := ""
	for i, s := range strs {
		if i > 0 {
			result += sep
		}
		result += s
	}
	return result
}

// RunAuthMigration executes the auth tables DDL.
func (r *UserRepository) RunAuthMigration() error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			email VARCHAR(255) UNIQUE NOT NULL,
			password_hash VARCHAR(255),
			full_name VARCHAR(255) NOT NULL,
			avatar_url TEXT DEFAULT '',
			provider VARCHAR(50) DEFAULT 'email',
			role VARCHAR(20) DEFAULT 'student',
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
		)`,
		`CREATE TABLE IF NOT EXISTS refresh_tokens (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			token_hash VARCHAR(255) NOT NULL,
			expires_at TIMESTAMPTZ NOT NULL,
			created_at TIMESTAMPTZ DEFAULT NOW(),
			revoked BOOLEAN DEFAULT FALSE
		)`,
		`CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id)`,
		`CREATE INDEX IF NOT EXISTS idx_refresh_tokens_hash ON refresh_tokens(token_hash)`,
		`CREATE TABLE IF NOT EXISTS password_reset_tokens (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			token_hash VARCHAR(255) NOT NULL,
			expires_at TIMESTAMPTZ NOT NULL,
			used BOOLEAN DEFAULT FALSE,
			created_at TIMESTAMPTZ DEFAULT NOW()
		)`,
		`CREATE INDEX IF NOT EXISTS idx_password_reset_user ON password_reset_tokens(user_id)`,
	}

	for _, q := range queries {
		if _, err := r.db.Exec(q); err != nil {
			return fmt.Errorf("RunAuthMigration: %w", err)
		}
	}

	log.Println("[UserRepo] ✅ Auth migration complete — users, refresh_tokens, password_reset_tokens")
	return nil
}
