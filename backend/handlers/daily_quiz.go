package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"bpsc-engine/services"
)

// DailyQuizHandler serves the daily mixed-subject PYQ quiz (15 questions).
type DailyQuizHandler struct {
	llm *services.LLMService
}

// NewDailyQuizHandler creates a new DailyQuizHandler.
func NewDailyQuizHandler(llm *services.LLMService) *DailyQuizHandler {
	return &DailyQuizHandler{llm: llm}
}

// HandleDailyQuiz generates 15 mixed-subject BPSC PYQ questions.
//
// POST /api/v1/daily-quiz
// No request body required — the server generates a fresh daily quiz.
func (h *DailyQuizHandler) HandleDailyQuiz(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed","code":405}`, http.StatusMethodNotAllowed)
		return
	}

	ctx := r.Context()

	log.Println("[DailyQuiz] Generating 15-question mixed PYQ daily quiz")

	ecosystem, err := h.llm.GenerateDailyQuiz(ctx)
	if err != nil {
		log.Printf("[DailyQuiz] ❌ LLM generation failed: %v", err)
		http.Error(w, `{"error":"Failed to generate daily quiz. Please try again.","code":500}`, http.StatusInternalServerError)
		return
	}

	log.Printf("[DailyQuiz] ✅ Generated %d questions", len(ecosystem.GeneratedQuestions))

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(ecosystem); err != nil {
		log.Printf("[DailyQuiz] ❌ Failed to encode response: %v", err)
	}
}
