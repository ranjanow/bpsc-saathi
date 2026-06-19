package models

import (
	"encoding/json"
	"time"
)

// ─────────────────────────────────────────────────────────────────────────────
// Bookmark is the canonical Go representation of a user_bookmarks row.
//
// QuestionData stores the complete GeneratedQuestion snapshot as raw JSON
// so it can be round-tripped without schema coupling to the questions table.
// The `db:"question_data"` tag is used by repository scanning helpers;
// the `json:"questionData"` tag drives the HTTP API contract.
// ─────────────────────────────────────────────────────────────────────────────
type Bookmark struct {
	// ID is the database-assigned UUID primary key.
	ID string `db:"id" json:"id"`

	// UserID is an opaque user identifier supplied by the client (e.g. Firebase
	// UID, Supabase UUID, or a dev-mode placeholder string).
	UserID string `db:"user_id" json:"userId"`

	// QuestionID mirrors the string ID returned by the LLM (e.g. "q-001").
	QuestionID string `db:"question_id" json:"questionId"`

	// ConceptTag is the denormalised subject/concept label for fast filtering
	// without having to unpack QuestionData on every query.
	ConceptTag string `db:"concept_tag" json:"conceptTag"`

	// QuestionData holds the full GeneratedQuestion snapshot serialised as
	// JSONB in PostgreSQL.  On reads it is unmarshalled into a
	// GeneratedQuestion struct; on writes it is marshalled from one.
	QuestionData GeneratedQuestion `db:"question_data" json:"questionData"`

	// CreatedAt is the bookmark creation timestamp (TIMESTAMPTZ → time.Time).
	CreatedAt time.Time `db:"created_at" json:"createdAt"`
}

// ─────────────────────────────────────────────────────────────────────────────
// BookmarkRequest is the inbound payload for POST /api/v1/bookmarks.
//
// The handler reads the user identity from the X-User-ID header (see
// BookmarkHandler.resolveUserID for the full resolution order) and merges it
// with the fields below to construct a Bookmark before persisting it.
// ─────────────────────────────────────────────────────────────────────────────
type BookmarkRequest struct {
	// QuestionID is the LLM-assigned question identifier (e.g. "q-001").
	// Required — returns 400 if absent.
	QuestionID string `json:"questionId"`

	// Question is the full GeneratedQuestion struct to snapshot.
	// Required — returns 400 if absent or unparseable.
	Question GeneratedQuestion `json:"question"`
}

// ─────────────────────────────────────────────────────────────────────────────
// BookmarkListResponse is the envelope returned by GET /api/v1/bookmarks.
// Wrapping the array in an object future-proofs the API for pagination fields.
// ─────────────────────────────────────────────────────────────────────────────
type BookmarkListResponse struct {
	Bookmarks []Bookmark `json:"bookmarks"`
	Count     int        `json:"count"`
}

// ─────────────────────────────────────────────────────────────────────────────
// bookmarkDataJSON is a private helper type used by the repository to
// marshal/unmarshal the question_data JSONB column cleanly without
// exposing raw []byte fields on the public Bookmark struct.
// ─────────────────────────────────────────────────────────────────────────────
type BookmarkDataJSON = json.RawMessage
