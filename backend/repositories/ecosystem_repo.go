package repositories

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"bpsc-engine/models"
)

// EcosystemRepository encapsulates all database operations for the
// question_ecosystems and generated_questions tables.
// Construct it with NewEcosystemRepository and inject any *sql.DB.
type EcosystemRepository struct {
	db *sql.DB
}

// NewEcosystemRepository returns a ready-to-use EcosystemRepository.
func NewEcosystemRepository(db *sql.DB) *EcosystemRepository {
	return &EcosystemRepository{db: db}
}

// ─────────────────────────────────────────────────────────────────────────────
// SaveEcosystem persists an AI-generated EcosystemResponse to PostgreSQL.
//
// Strategy:
//   - Opens a serialisable transaction so the ecosystem row and all its
//     question rows are written atomically — either everything commits or
//     nothing does (no orphaned questions, no empty ecosystems).
//   - Converts []string slices to JSONB via encoding/json to satisfy the
//     JSONB columns defined in the schema.
//   - Returns the new UUID assigned to the ecosystem row.
//
// ─────────────────────────────────────────────────────────────────────────────
func (r *EcosystemRepository) SaveEcosystem(
	ctx context.Context,
	eco *models.EcosystemResponse,
) (string, error) {

	// ── 1. Marshal the []string slice to JSON for the JSONB column ────────────
	conceptsJSON, err := json.Marshal(eco.ConnectedStaticConcepts)
	if err != nil {
		return "", fmt.Errorf("repositories: marshal connected_static_concepts: %w", err)
	}

	// ── 2. Begin transaction ──────────────────────────────────────────────────
	tx, err := r.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return "", fmt.Errorf("repositories: begin transaction: %w", err)
	}
	// Ensure the transaction is always resolved — roll back on any early return.
	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback()
			panic(p) // re-panic after rollback
		}
	}()

	// ── 3. Insert the parent ecosystem row ───────────────────────────────────
	const insertEcosystem = `
		INSERT INTO question_ecosystems
			(core_topic, connected_static_concepts)
		VALUES
			($1, $2)
		RETURNING id`

	var ecosystemID string
	err = tx.QueryRowContext(ctx, insertEcosystem, eco.CoreTopic, conceptsJSON).Scan(&ecosystemID)
	if err != nil {
		_ = tx.Rollback()
		return "", fmt.Errorf("repositories: insert ecosystem: %w", err)
	}

	// ── 4. Insert all generated questions ────────────────────────────────────
	// Note: 'id' is intentionally omitted from the column list so PostgreSQL
	// uses DEFAULT gen_random_uuid(). The LLM returns string IDs like "q-001"
	// which cannot be cast to UUID, so we let the DB own all PK generation.
	const insertQuestion = `
		INSERT INTO generated_questions
			(ecosystem_id, question_en, question_hi, options_en, options_hi,
			 correct_option_index, explanation_en, explanation_hi, difficulty, subject, position)
		VALUES
			($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`

	for i, q := range eco.GeneratedQuestions {
		optionsEnJSON, err := json.Marshal(q.OptionsEN)
		if err != nil {
			_ = tx.Rollback()
			return "", fmt.Errorf("repositories: marshal options_en for question %d: %w", i, err)
		}
		optionsHiJSON, err := json.Marshal(q.OptionsHI)
		if err != nil {
			_ = tx.Rollback()
			return "", fmt.Errorf("repositories: marshal options_hi for question %d: %w", i, err)
		}

		_, err = tx.ExecContext(
			ctx,
			insertQuestion,
			ecosystemID,          // $1
			q.QuestionEN,         // $2
			q.QuestionHI,         // $3
			optionsEnJSON,        // $4
			optionsHiJSON,        // $5
			q.CorrectOptionIndex, // $6
			q.ExplanationEN,      // $7
			q.ExplanationHI,      // $8
			q.Difficulty,         // $9
			q.Subject,            // $10
			i,                    // $11 — position preserves AI ordering
		)
		if err != nil {
			_ = tx.Rollback()
			return "", fmt.Errorf("repositories: insert question %d: %w", i, err)
		}
	}

	// ── 5. Commit ─────────────────────────────────────────────────────────────
	if err := tx.Commit(); err != nil {
		return "", fmt.Errorf("repositories: commit transaction: %w", err)
	}

	return ecosystemID, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// GetEcosystemByID fetches a full ecosystem (header + questions) by its UUID.
// Returns sql.ErrNoRows if not found — callers should handle that explicitly.
// ─────────────────────────────────────────────────────────────────────────────
func (r *EcosystemRepository) GetEcosystemByID(
	ctx context.Context,
	id string,
) (*models.EcosystemResponse, error) {

	// ── Fetch the parent row ──────────────────────────────────────────────────
	const selectEcosystem = `
		SELECT core_topic, connected_static_concepts
		FROM   question_ecosystems
		WHERE  id = $1 AND is_archived = FALSE`

	var (
		coreTopic    string
		conceptsJSON []byte
	)
	err := r.db.QueryRowContext(ctx, selectEcosystem, id).Scan(&coreTopic, &conceptsJSON)
	if err != nil {
		return nil, fmt.Errorf("repositories: get ecosystem %s: %w", id, err)
	}

	var concepts []string
	if err := json.Unmarshal(conceptsJSON, &concepts); err != nil {
		return nil, fmt.Errorf("repositories: unmarshal connected_static_concepts: %w", err)
	}

	// ── Fetch child questions ordered by position ─────────────────────────────
	const selectQuestions = `
		SELECT id, question_en, question_hi, options_en, options_hi,
		       correct_option_index, explanation_en, explanation_hi, difficulty, subject
		FROM   generated_questions
		WHERE  ecosystem_id = $1
		ORDER  BY position ASC`

	rows, err := r.db.QueryContext(ctx, selectQuestions, id)
	if err != nil {
		return nil, fmt.Errorf("repositories: get questions for ecosystem %s: %w", id, err)
	}
	defer rows.Close()

	var questions []models.GeneratedQuestion
	for rows.Next() {
		var (
			q             models.GeneratedQuestion
			optionsEnJSON []byte
			optionsHiJSON []byte
		)
		if err := rows.Scan(
			&q.ID,
			&q.QuestionEN,
			&q.QuestionHI,
			&optionsEnJSON,
			&optionsHiJSON,
			&q.CorrectOptionIndex,
			&q.ExplanationEN,
			&q.ExplanationHI,
			&q.Difficulty,
			&q.Subject,
		); err != nil {
			return nil, fmt.Errorf("repositories: scan question row: %w", err)
		}
		if err := json.Unmarshal(optionsEnJSON, &q.OptionsEN); err != nil {
			return nil, fmt.Errorf("repositories: unmarshal options_en: %w", err)
		}
		if err := json.Unmarshal(optionsHiJSON, &q.OptionsHI); err != nil {
			return nil, fmt.Errorf("repositories: unmarshal options_hi: %w", err)
		}
		questions = append(questions, q)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("repositories: iterate question rows: %w", err)
	}

	return &models.EcosystemResponse{
		CoreTopic:               coreTopic,
		ConnectedStaticConcepts: concepts,
		GeneratedQuestions:      questions,
	}, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// ListEcosystems returns a paginated, lightweight list of ecosystems
// (no questions — just header data) sorted newest-first.
//
// Parameters:
//   - limit:  max rows to return  (use 20 as a sane default)
//   - offset: rows to skip        (use 0 for the first page)
// ─────────────────────────────────────────────────────────────────────────────
func (r *EcosystemRepository) ListEcosystems(
	ctx context.Context,
	limit, offset int,
) ([]EcosystemSummary, error) {

	const query = `
		SELECT   id, core_topic, created_at,
		         jsonb_array_length(connected_static_concepts) AS concept_count
		FROM     question_ecosystems
		WHERE    is_archived = FALSE
		ORDER BY created_at DESC
		LIMIT    $1 OFFSET $2`

	rows, err := r.db.QueryContext(ctx, query, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("repositories: list ecosystems: %w", err)
	}
	defer rows.Close()

	var summaries []EcosystemSummary
	for rows.Next() {
		var s EcosystemSummary
		if err := rows.Scan(&s.ID, &s.CoreTopic, &s.CreatedAt, &s.ConceptCount); err != nil {
			return nil, fmt.Errorf("repositories: scan ecosystem summary: %w", err)
		}
		summaries = append(summaries, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("repositories: iterate ecosystem rows: %w", err)
	}

	return summaries, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// DeleteEcosystem soft-deletes an ecosystem by setting is_archived = TRUE.
// Hard-delete (CASCADE) is available via the SQL schema for admin tooling.
// ─────────────────────────────────────────────────────────────────────────────
func (r *EcosystemRepository) DeleteEcosystem(ctx context.Context, id string) error {
	const query = `UPDATE question_ecosystems SET is_archived = TRUE WHERE id = $1`
	result, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("repositories: soft-delete ecosystem %s: %w", id, err)
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return fmt.Errorf("repositories: ecosystem %s not found", id)
	}
	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// EcosystemSummary is a lightweight projection used by ListEcosystems.
// It avoids loading all questions when only header data is needed.
// ─────────────────────────────────────────────────────────────────────────────
type EcosystemSummary struct {
	ID           string    `json:"id"`
	CoreTopic    string    `json:"coreTopic"`
	CreatedAt    time.Time `json:"createdAt"`
	ConceptCount int       `json:"conceptCount"`
}
