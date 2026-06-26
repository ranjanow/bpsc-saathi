package handlers

import (
	"encoding/json"
	"net/http"

	"bpsc-engine/repositories"
)

// AnalyticsHandler handles GET /api/v1/analytics/* endpoints.
type AnalyticsHandler struct {
	repo *repositories.AnalyticsRepository
}

func NewAnalyticsHandler(repo *repositories.AnalyticsRepository) *AnalyticsHandler {
	return &AnalyticsHandler{repo: repo}
}

// HandleDashboard returns GET /api/v1/analytics/dashboard
func (h *AnalyticsHandler) HandleDashboard(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	dash, err := h.repo.GetDashboard(claims.UserID)
	if err != nil {
		jsonError(w, "failed to get analytics", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dash)
}

// HandleProgress returns GET /api/v1/analytics/progress (subject mastery)
func (h *AnalyticsHandler) HandleProgress(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	mastery, err := h.repo.GetSubjectMastery(claims.UserID)
	if err != nil {
		jsonError(w, "failed to get progress", http.StatusInternalServerError)
		return
	}
	if mastery == nil {
		mastery = []repositories.SubjectMastery{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"subjects": mastery})
}

// HandleStreak returns GET /api/v1/analytics/streak
func (h *AnalyticsHandler) HandleStreak(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	streak, err := h.repo.GetStreak(claims.UserID)
	if err != nil {
		jsonError(w, "failed to get streak", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(streak)
}

// HandleRecordAttempt handles POST /api/v1/analytics/record-attempt
func (h *AnalyticsHandler) HandleRecordAttempt(w http.ResponseWriter, r *http.Request) {
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
		QuizType   string `json:"quizType"`
		Subject    string `json:"subject"`
		Total      int    `json:"totalQuestions"`
		Correct    int    `json:"correctAnswers"`
		TimeSpent  int    `json:"timeSpentSeconds"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	if err := h.repo.RecordQuizAttempt(claims.UserID, req.QuizType, req.Subject, req.Total, req.Correct, req.TimeSpent); err != nil {
		jsonError(w, "failed to record attempt", http.StatusInternalServerError)
		return
	}

	_ = h.repo.RecordActivity(claims.UserID, "quiz")

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "recorded"})
}
