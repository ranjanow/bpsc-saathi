package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"bpsc-engine/models"
)

// TutorHandler manages the deep dive inline tutor endpoints.
type TutorHandler struct {
	llm LLMService
}

func NewTutorHandler(llm LLMService) *TutorHandler {
	return &TutorHandler{llm: llm}
}

// HandleTutorRequest handles POST /api/v1/tutor.
func (h *TutorHandler) HandleTutorRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, "Method not allowed. Use POST.", http.StatusMethodNotAllowed)
		return
	}

	defer r.Body.Close()

	var req models.TutorRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
		return
	}

	if req.QuestionText == "" || req.DoubtQuery == "" {
		writeError(w, "Fields 'question_text' and 'doubt_query' are required", http.StatusBadRequest)
		return
	}

	log.Printf("[TutorHandler] Processing doubt for question: %q", req.QuestionText)

	prompt := fmt.Sprintf(`You are an AI Socratic tutor. A student has a doubt about a question.
Instead of giving the direct answer, guide the student to the correct answer by asking leading questions.
Here is the context:
Question: %s
Correct Answer: %s
Original Explanation: %s
Student's Doubt: %s

Respond to the student's doubt directly, keeping your response short and adopting a Socratic approach.`, req.QuestionText, req.CorrectAnswer, req.OriginalExplanation, req.DoubtQuery)

	response, err := h.llm.GenerateContent(r.Context(), prompt)
	if err != nil {
		log.Printf("[TutorHandler] 🚨 LLM error: %v", err)
		writeError(w, fmt.Sprintf("Tutor generation failed: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[TutorHandler] ✅ Tutor responded successfully")
	writeJSON(w, http.StatusOK, models.TutorResponse{Response: response})
}
