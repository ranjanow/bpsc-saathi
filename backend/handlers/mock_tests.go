package handlers

import (
	"encoding/json"
	"net/http"

	"bpsc-engine/repositories"
)

// ─────────────────────────────────────────────────────────────────────────────
// MockTestHandler — Feature 7: Mock Test Engine
// ─────────────────────────────────────────────────────────────────────────────

type MockTestHandler struct {
	repo *repositories.FeaturesRepository
}

func NewMockTestHandler(repo *repositories.FeaturesRepository) *MockTestHandler {
	return &MockTestHandler{repo: repo}
}

// HandleListTests returns GET /api/v1/mock-tests
func (h *MockTestHandler) HandleListTests(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	tests, err := h.repo.GetMockTests()
	if err != nil {
		jsonError(w, "failed to list tests", http.StatusInternalServerError)
		return
	}
	if tests == nil {
		tests = []repositories.MockTest{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"tests": tests})
}

// HandleGetTest returns GET /api/v1/mock-tests/detail?id=xxx
func (h *MockTestHandler) HandleGetTest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		jsonError(w, "id required", http.StatusBadRequest)
		return
	}

	test, err := h.repo.GetMockTest(id)
	if err != nil || test == nil {
		jsonError(w, "test not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(test)
}

// HandleStartTest handles POST /api/v1/mock-tests/start
func (h *MockTestHandler) HandleStartTest(w http.ResponseWriter, r *http.Request) {
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
		MockTestID string `json:"mockTestId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	test, err := h.repo.GetMockTest(req.MockTestID)
	if err != nil || test == nil {
		jsonError(w, "test not found", http.StatusNotFound)
		return
	}

	attempt, err := h.repo.StartMockAttempt(claims.UserID, req.MockTestID, test.DurationMinutes*60)
	if err != nil {
		jsonError(w, "failed to start test", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(attempt)
}

// HandleSubmitTest handles POST /api/v1/mock-tests/submit
func (h *MockTestHandler) HandleSubmitTest(w http.ResponseWriter, r *http.Request) {
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
		AttemptID string                 `json:"attemptId"`
		Answers   map[string]interface{} `json:"answers"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	answersJSON, _ := json.Marshal(req.Answers)

	// Calculate result (simplified — in production would check against answer key)
	total := len(req.Answers)
	correct := 0
	incorrect := 0
	attempted := total

	for range req.Answers {
		// In production: compare against actual answers
		// For now, mark as tracked
	}

	unattempted := 150 - attempted
	if unattempted < 0 {
		unattempted = 0
	}
	rawScore := float64(correct) - float64(incorrect)*0.33
	percentage := 0.0
	if total > 0 {
		percentage = rawScore / float64(150) * 100
	}

	result := &repositories.MockResult{
		AttemptID:        claims.UserID,
		TotalQuestions:   150,
		Attempted:        attempted,
		Correct:          correct,
		Incorrect:        incorrect,
		Unattempted:      unattempted,
		RawScore:         rawScore,
		Percentage:       percentage,
		SubjectBreakdown: json.RawMessage("{}"),
	}

	if err := h.repo.SubmitMockTest(req.AttemptID, answersJSON, result); err != nil {
		jsonError(w, "failed to submit test", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "test submitted",
		"result":  result,
	})
}

// HandleGetResult returns GET /api/v1/mock-tests/result?attemptId=xxx
func (h *MockTestHandler) HandleGetResult(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	attemptID := r.URL.Query().Get("attemptId")
	if attemptID == "" {
		jsonError(w, "attemptId required", http.StatusBadRequest)
		return
	}

	result, err := h.repo.GetMockResult(attemptID)
	if err != nil || result == nil {
		jsonError(w, "result not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}
