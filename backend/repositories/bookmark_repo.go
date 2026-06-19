package repositories

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"bpsc-engine/models"
)

// ─────────────────────────────────────────────────────────────────────────────
// BookmarkRepository defines the contract for bookmark persistence operations.
//
// An interface is declared here (rather than just the concrete struct) to make
// the handler layer unit-testable without a live database.  Any mock can
// implement this interface in tests.
// ─────────────────────────────────────────────────────────────────────────────
type BookmarkRepository interface {
	// Save persists a new bookmark.  If the (user_id, question_id) pair already
	// exists the operation is silently idempotent — ON CONFLICT DO NOTHING means
	// no row is modified and no error is returned.
	Save(ctx context.Context, b *models.Bookmark) error

	// GetByUserID fetches all bookmarks for the given user, ordered by creation
	// time descending (most-recently saved first).
	// Returns an empty slice (not nil) when the user has no bookmarks.
	GetByUserID(ctx context.Context, userID string) ([]models.Bookmark, error)

	// Delete removes a single bookmark identified by (userID, questionID).
	// Returns ErrBookmarkNotFound if no matching row exists so the handler
	// can distinguish a legitimate 404 from a database error.
	Delete(ctx context.Context, userID string, questionID string) error
}

// ─────────────────────────────────────────────────────────────────────────────
// ErrBookmarkNotFound is returned by Delete when no matching row was found.
// It is a sentinel value — callers can compare with errors.Is().
// ─────────────────────────────────────────────────────────────────────────────
var ErrBookmarkNotFound = fmt.Errorf("repositories: bookmark not found")

// ─────────────────────────────────────────────────────────────────────────────
// PostgresBookmarkRepository is the concrete, production implementation of
// BookmarkRepository backed by a PostgreSQL connection pool.
//
// Construct it with NewPostgresBookmarkRepository and inject any *sql.DB that
// is already connected and ping-verified.
// ─────────────────────────────────────────────────────────────────────────────
type PostgresBookmarkRepository struct {
	db *sql.DB
}

// NewPostgresBookmarkRepository returns a ready-to-use repository.
// db must be non-nil; pass the same *sql.DB used by EcosystemRepository.
func NewPostgresBookmarkRepository(db *sql.DB) *PostgresBookmarkRepository {
	return &PostgresBookmarkRepository{db: db}
}

// Compile-time assertion: PostgresBookmarkRepository must satisfy the interface.
var _ BookmarkRepository = (*PostgresBookmarkRepository)(nil)

// ─────────────────────────────────────────────────────────────────────────────
// Save inserts a new bookmark row.
//
// ON CONFLICT DO NOTHING makes this operation fully idempotent: if the user
// has already bookmarked the same question, the call returns nil without
// modifying any data.  This is preferable to ON CONFLICT DO UPDATE because
// bookmarks are immutable once created — we never want to silently overwrite
// the saved question snapshot.
// ─────────────────────────────────────────────────────────────────────────────
func (r *PostgresBookmarkRepository) Save(ctx context.Context, b *models.Bookmark) error {
	// Serialise the question snapshot to JSONB.
	questionDataJSON, err := json.Marshal(b.QuestionData)
	if err != nil {
		return fmt.Errorf("repositories: marshal question_data for bookmark: %w", err)
	}

	const query = `
		INSERT INTO user_bookmarks
			(user_id, question_id, concept_tag, question_data)
		VALUES
			($1, $2, $3, $4)
		ON CONFLICT (user_id, question_id) DO NOTHING
		RETURNING id, created_at`

	// RETURNING lets us populate the auto-generated fields on the struct
	// without a second round-trip to the database.
	// If ON CONFLICT fires (duplicate), no row is returned and Scan will
	// return sql.ErrNoRows — we treat that as a success.
	row := r.db.QueryRowContext(
		ctx, query,
		b.UserID,         // $1
		b.QuestionID,     // $2
		b.ConceptTag,     // $3
		questionDataJSON, // $4  — JSONB
	)

	if err := row.Scan(&b.ID, &b.CreatedAt); err != nil {
		if err == sql.ErrNoRows {
			// The ON CONFLICT DO NOTHING clause fired — row already exists.
			// This is not an error from the caller's perspective.
			return nil
		}
		return fmt.Errorf("repositories: save bookmark for user=%s question=%s: %w",
			b.UserID, b.QuestionID, err)
	}

	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// GetByUserID fetches every bookmark saved by the given user.
//
// Results are ordered by created_at DESC so the client's "Saved for Review"
// list shows the most recently bookmarked question at the top — consistent
// with the UX convention of most apps.
//
// The question_data JSONB column is scanned into a []byte intermediate and
// then unmarshalled into a GeneratedQuestion struct.  This avoids exposing
// raw JSON bytes on the public Bookmark model.
// ─────────────────────────────────────────────────────────────────────────────
func (r *PostgresBookmarkRepository) GetByUserID(
	ctx context.Context,
	userID string,
) ([]models.Bookmark, error) {

	const query = `
		SELECT
			id,
			user_id,
			question_id,
			concept_tag,
			question_data,
			created_at
		FROM  user_bookmarks
		WHERE user_id = $1
		ORDER BY created_at DESC`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("repositories: get bookmarks for user=%s: %w", userID, err)
	}
	defer rows.Close()

	// Pre-allocate with zero length but non-nil so the JSON encoding of an
	// empty list is [] rather than null.
	bookmarks := make([]models.Bookmark, 0)

	for rows.Next() {
		var (
			b               models.Bookmark
			questionDataRaw []byte // intermediate for JSONB → struct conversion
		)

		if err := rows.Scan(
			&b.ID,
			&b.UserID,
			&b.QuestionID,
			&b.ConceptTag,
			&questionDataRaw,
			&b.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("repositories: scan bookmark row for user=%s: %w", userID, err)
		}

		// Deserialise the JSONB snapshot back into a typed struct.
		if err := json.Unmarshal(questionDataRaw, &b.QuestionData); err != nil {
			// Log a warning but do NOT abort the whole list — a corrupted
			// snapshot for one question should not hide all other bookmarks.
			// The partially-populated struct (zero-value QuestionData) is still
			// returned so the client can render the question_id at minimum.
			//
			// In production, pair this with an alerting rule on the log line.
			fmt.Printf("[WARN] repositories: unmarshal question_data for bookmark id=%s: %v\n", b.ID, err)
		}

		bookmarks = append(bookmarks, b)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("repositories: iterate bookmark rows for user=%s: %w", userID, err)
	}

	return bookmarks, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete removes a single bookmark identified by (userID, questionID).
//
// The DELETE is scoped to both user_id AND question_id so a user can never
// delete another user's bookmark, even if they know the question_id.
//
// Returns ErrBookmarkNotFound (a sentinel) when RowsAffected == 0 so the
// handler can map this to an HTTP 404 without string-matching error messages.
// ─────────────────────────────────────────────────────────────────────────────
func (r *PostgresBookmarkRepository) Delete(
	ctx context.Context,
	userID string,
	questionID string,
) error {

	const query = `
		DELETE FROM user_bookmarks
		WHERE user_id    = $1
		  AND question_id = $2`

	result, err := r.db.ExecContext(ctx, query, userID, questionID)
	if err != nil {
		return fmt.Errorf("repositories: delete bookmark user=%s question=%s: %w",
			userID, questionID, err)
	}

	n, err := result.RowsAffected()
	if err != nil {
		// RowsAffected errors are driver-specific and rare; surface as-is.
		return fmt.Errorf("repositories: check rows affected for delete: %w", err)
	}
	if n == 0 {
		return ErrBookmarkNotFound
	}

	return nil
}
