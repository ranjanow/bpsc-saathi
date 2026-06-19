package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"

	"bpsc-engine/models"
	"bpsc-engine/repositories"
)

// ─────────────────────────────────────────────────────────────────────────────
// BookmarkHandler serves the three bookmark endpoints.
//
// Dependency injection mirrors EcosystemHandler: the concrete repository is
// injected at startup so the handler itself is fully testable with a mock.
// ─────────────────────────────────────────────────────────────────────────────
type BookmarkHandler struct {
	repo repositories.BookmarkRepository
}

// NewBookmarkHandler returns a ready-to-use BookmarkHandler.
// repo must be non-nil; pass a *repositories.PostgresBookmarkRepository
// constructed in main.go.
func NewBookmarkHandler(repo repositories.BookmarkRepository) *BookmarkHandler {
	return &BookmarkHandler{repo: repo}
}

// ─────────────────────────────────────────────────────────────────────────────
// HandleCreateBookmark saves a question as a bookmark for the requesting user.
//
// POST /api/v1/bookmarks
//
// Request headers:
//   X-User-ID: <userID>   — opaque user identifier (see resolveUserID).
//
// Request body (application/json):
//
//	{
//	  "questionId": "q-001",
//	  "question": { ...GeneratedQuestion fields... }
//	}
//
// Responses:
//
//	201 Created         — bookmark saved (or silently accepted as duplicate).
//	                      Body: { "id": "<uuid>", "userId": ..., ... }
//	400 Bad Request     — missing/invalid body or missing X-User-ID header.
//	500 Internal Error  — database write failure.
// ─────────────────────────────────────────────────────────────────────────────
func (h *BookmarkHandler) HandleCreateBookmark(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, "Method not allowed. Use POST.", http.StatusMethodNotAllowed)
		return
	}

	// ── 1. Resolve caller identity ────────────────────────────────────────────
	userID, err := resolveUserID(r)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	// ── 2. Decode and validate request body ───────────────────────────────────
	defer r.Body.Close()

	var req models.BookmarkRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w,
			fmt.Sprintf("Invalid request body: %v", err),
			http.StatusBadRequest,
		)
		return
	}

	if req.QuestionID == "" {
		writeError(w, "Field 'questionId' is required", http.StatusBadRequest)
		return
	}
	if req.Question.QuestionEN == "" {
		writeError(w, "Field 'question.question_en' is required and must not be empty", http.StatusBadRequest)
		return
	}

	// ── 3. Construct the Bookmark domain object ───────────────────────────────
	// ConceptTag is denormalised from the question's Subject field so the
	// repository can filter by concept without touching the JSONB blob.
	b := &models.Bookmark{
		UserID:       userID,
		QuestionID:   req.QuestionID,
		ConceptTag:   req.Question.Subject,
		QuestionData: req.Question,
	}

	// ── 4. Persist ────────────────────────────────────────────────────────────
	if err := h.repo.Save(r.Context(), b); err != nil {
		log.Printf("[Bookmark] ❌ Save failed user=%s question=%s: %v", userID, req.QuestionID, err)
		writeError(w,
			fmt.Sprintf("Failed to save bookmark: %v", err),
			http.StatusInternalServerError,
		)
		return
	}

	log.Printf("[Bookmark] ✅ Saved bookmark user=%s question=%s id=%s", userID, req.QuestionID, b.ID)

	// ── 5. Respond 201 Created ────────────────────────────────────────────────
	// We return the full bookmark (including the DB-assigned id and created_at)
	// so the client can immediately display it without a second GET.
	writeJSON(w, http.StatusCreated, b)
}

// ─────────────────────────────────────────────────────────────────────────────
// HandleGetBookmarks returns all bookmarks saved by the requesting user.
//
// GET /api/v1/bookmarks
//
// Request headers:
//   X-User-ID: <userID>
//
// Responses:
//
//	200 OK          — { "bookmarks": [...], "count": N }
//	                  Empty list returns { "bookmarks": [], "count": 0 }.
//	400 Bad Request — missing X-User-ID header.
//	500 Internal    — database read failure.
// ─────────────────────────────────────────────────────────────────────────────
func (h *BookmarkHandler) HandleGetBookmarks(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, "Method not allowed. Use GET.", http.StatusMethodNotAllowed)
		return
	}

	// ── 1. Resolve caller identity ────────────────────────────────────────────
	userID, err := resolveUserID(r)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	// ── 2. Fetch from repository ──────────────────────────────────────────────
	bookmarks, err := h.repo.GetByUserID(r.Context(), userID)
	if err != nil {
		log.Printf("[Bookmark] ❌ GetByUserID failed user=%s: %v", userID, err)
		writeError(w,
			fmt.Sprintf("Failed to retrieve bookmarks: %v", err),
			http.StatusInternalServerError,
		)
		return
	}

	log.Printf("[Bookmark] ✅ Fetched %d bookmark(s) for user=%s", len(bookmarks), userID)

	// ── 3. Respond 200 OK ─────────────────────────────────────────────────────
	writeJSON(w, http.StatusOK, models.BookmarkListResponse{
		Bookmarks: bookmarks,
		Count:     len(bookmarks),
	})
}

// ─────────────────────────────────────────────────────────────────────────────
// HandleDeleteBookmark removes a bookmark for the requesting user.
//
// DELETE /api/v1/bookmarks
//
// Request headers:
//   X-User-ID: <userID>
//
// Request body (application/json):
//
//	{ "questionId": "q-001" }
//
// The user identity is always taken from the header — the body never needs
// to supply it, preventing any user from accidentally deleting another user's
// bookmark by submitting a different userID.
//
// Responses:
//
//	204 No Content  — bookmark deleted.
//	400 Bad Request — missing header or invalid body.
//	404 Not Found   — no matching bookmark exists.
//	500 Internal    — database error.
// ─────────────────────────────────────────────────────────────────────────────
func (h *BookmarkHandler) HandleDeleteBookmark(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		writeError(w, "Method not allowed. Use DELETE.", http.StatusMethodNotAllowed)
		return
	}

	// ── 1. Resolve caller identity ────────────────────────────────────────────
	userID, err := resolveUserID(r)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	// ── 2. Decode request body ────────────────────────────────────────────────
	// We accept the question_id in the body rather than a URL path segment
	// because question IDs ("q-001") may be opaque strings that don't need
	// to be part of the URL surface, and DELETE with a body is valid HTTP.
	defer r.Body.Close()

	var payload struct {
		QuestionID string `json:"questionId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeError(w,
			fmt.Sprintf("Invalid request body: %v", err),
			http.StatusBadRequest,
		)
		return
	}

	if payload.QuestionID == "" {
		writeError(w, "Field 'questionId' is required", http.StatusBadRequest)
		return
	}

	// ── 3. Delete via repository ──────────────────────────────────────────────
	if err := h.repo.Delete(r.Context(), userID, payload.QuestionID); err != nil {
		if errors.Is(err, repositories.ErrBookmarkNotFound) {
			writeError(w,
				fmt.Sprintf("Bookmark not found for question '%s'", payload.QuestionID),
				http.StatusNotFound,
			)
			return
		}
		log.Printf("[Bookmark] ❌ Delete failed user=%s question=%s: %v", userID, payload.QuestionID, err)
		writeError(w,
			fmt.Sprintf("Failed to delete bookmark: %v", err),
			http.StatusInternalServerError,
		)
		return
	}

	log.Printf("[Bookmark] ✅ Deleted bookmark user=%s question=%s", userID, payload.QuestionID)

	// ── 4. Respond 204 No Content ─────────────────────────────────────────────
	// 204 must not include a response body per RFC 9110 §15.3.5.
	w.WriteHeader(http.StatusNoContent)
}

// ─────────────────────────────────────────────────────────────────────────────
// resolveUserID extracts the caller's user identifier from the request.
//
// Resolution order:
//  1. X-User-ID header   — primary source; set by the API gateway or the
//                          Flutter client after authentication.
//  2. Authorization header (Bearer token prefix stripped) — fallback when a
//                          raw token is forwarded directly.
//
// In production, replace this function with a proper JWT verification
// middleware (e.g. Firebase Admin SDK or Supabase JWT validation) that
// attaches the verified user ID to the request context.  The handler then
// reads from the context key instead of the header.
//
// Returns a non-nil error when no user identity can be determined.
// ─────────────────────────────────────────────────────────────────────────────
func resolveUserID(r *http.Request) (string, error) {
	// Primary: explicit X-User-ID header.
	if uid := strings.TrimSpace(r.Header.Get("X-User-ID")); uid != "" {
		return uid, nil
	}

	// Fallback: strip "Bearer " prefix from Authorization header.
	if auth := r.Header.Get("Authorization"); auth != "" {
		token := strings.TrimPrefix(auth, "Bearer ")
		token = strings.TrimSpace(token)
		if token != "" {
			return token, nil
		}
	}

	return "", fmt.Errorf("user identity required: set the X-User-ID header")
}
