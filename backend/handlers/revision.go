package handlers

import (
	"encoding/json"
	"net/http"

	"bpsc-engine/repositories"
)

// ─────────────────────────────────────────────────────────────────────────────
// RevisionHandler — SM-2 spaced repetition
// Feature 6: Smart Revision Engine
// ─────────────────────────────────────────────────────────────────────────────

type RevisionHandler struct {
	repo *repositories.FeaturesRepository
}

func NewRevisionHandler(repo *repositories.FeaturesRepository) *RevisionHandler {
	return &RevisionHandler{repo: repo}
}

// HandleGetRevisions returns GET /api/v1/revision/today
func (h *RevisionHandler) HandleGetRevisions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	items, err := h.repo.GetTodayRevisions(claims.UserID)
	if err != nil {
		jsonError(w, "failed to get revisions", http.StatusInternalServerError)
		return
	}
	if items == nil {
		items = []repositories.RevisionItem{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"revisions": items, "count": len(items)})
}

// HandleAddRevision handles POST /api/v1/revision/add
func (h *RevisionHandler) HandleAddRevision(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req struct {
		Subject    string `json:"subject"`
		Topic      string `json:"topic"`
		Difficulty string `json:"difficulty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if req.Subject == "" || req.Topic == "" {
		jsonError(w, "subject and topic required", http.StatusBadRequest)
		return
	}
	if req.Difficulty == "" {
		req.Difficulty = "medium"
	}

	if err := h.repo.AddToRevisionQueue(claims.UserID, req.Subject, req.Topic, req.Difficulty); err != nil {
		jsonError(w, "failed to add to revision queue", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "added to revision queue"})
}

// HandleCompleteRevision handles POST /api/v1/revision/complete
func (h *RevisionHandler) HandleCompleteRevision(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req struct {
		ItemID  string `json:"itemId"`
		Quality int    `json:"quality"` // 0-5 (SM-2 quality rating)
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if req.ItemID == "" {
		jsonError(w, "itemId required", http.StatusBadRequest)
		return
	}
	if req.Quality < 0 || req.Quality > 5 {
		jsonError(w, "quality must be 0-5", http.StatusBadRequest)
		return
	}

	if err := h.repo.CompleteRevision(req.ItemID, req.Quality); err != nil {
		jsonError(w, "failed to complete revision", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "revision recorded"})
}
