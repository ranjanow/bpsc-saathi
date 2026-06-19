package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"bpsc-engine/models"
	"bpsc-engine/repositories"
)

// ─────────────────────────────────────────────────────────────────────────────
// Profile Handler — DB-backed user profile CRUD
//
// Endpoints:
//   GET    /api/v1/profile          → returns the authenticated user's profile
//   PUT    /api/v1/profile          → updates profile fields
//   GET    /api/v1/profile/stats    → returns computed stats
// ─────────────────────────────────────────────────────────────────────────────

// ProfileHandler manages user profile operations backed by PostgreSQL.
type ProfileHandler struct {
	userRepo *repositories.UserRepository
}

// NewProfileHandler creates a DB-backed profile handler.
func NewProfileHandler(userRepo *repositories.UserRepository) *ProfileHandler {
	return &ProfileHandler{userRepo: userRepo}
}

// HandleGetProfile returns the authenticated user's profile.
func (h *ProfileHandler) HandleGetProfile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	user, err := h.userRepo.GetUserByID(claims.UserID)
	if err != nil || user == nil {
		log.Printf("[Profile] ❌ Failed to get user: %v", err)
		jsonError(w, "user not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user.ToPublic())
}

// HandleUpdateProfile updates mutable profile fields.
func (h *ProfileHandler) HandleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req models.UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON body", http.StatusBadRequest)
		return
	}

	updated, err := h.userRepo.UpdateUser(claims.UserID, &req)
	if err != nil {
		log.Printf("[Profile] ❌ Failed to update user: %v", err)
		jsonError(w, "failed to update profile", http.StatusInternalServerError)
		return
	}

	log.Printf("[Profile] ✅ Updated user=%s", claims.UserID)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(updated.ToPublic())
}

// HandleGetStats returns the user's stats (XP, streak, accuracy, quizzes).
func (h *ProfileHandler) HandleGetStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	user, err := h.userRepo.GetUserByID(claims.UserID)
	if err != nil || user == nil {
		log.Printf("[Profile] ❌ Failed to get user stats: %v", err)
		jsonError(w, "user not found", http.StatusNotFound)
		return
	}

	stats := map[string]interface{}{
		"totalXp":      user.TotalXP,
		"streakDays":   user.StreakDays,
		"quizzesTaken": user.QuizzesTaken,
		"accuracy":     user.Accuracy,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}
