package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"

	"bpsc-engine/models"
)

// MainsEvaluationHandler manages the BPSC Mains essay evaluation endpoint.
type MainsEvaluationHandler struct {
	llm LLMService
}

// NewMainsEvaluationHandler creates a new instance of MainsEvaluationHandler.
func NewMainsEvaluationHandler(llm LLMService) *MainsEvaluationHandler {
	return &MainsEvaluationHandler{llm: llm}
}

// HandleMainsEvaluation handles POST /api/v1/mains-evaluate.
func (h *MainsEvaluationHandler) HandleMainsEvaluation(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, "Method not allowed. Use POST.", http.StatusMethodNotAllowed)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MB limit
	defer r.Body.Close()

	var req models.MainsEvaluationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
		return
	}

	if req.Topic == "" || req.Essay == "" {
		writeError(w, "Fields 'topic' and 'essay' are required", http.StatusBadRequest)
		return
	}
	if len(req.Topic) > 200 {
		writeError(w, "Topic must be 200 characters or fewer", http.StatusBadRequest)
		return
	}
	if len(req.Essay) > 10000 {
		writeError(w, "Essay must be 10,000 characters or fewer", http.StatusBadRequest)
		return
	}

	log.Printf("[MainsEvaluationHandler] Evaluating essay for topic: %q", req.Topic)

	prompt := fmt.Sprintf(`Act as a strict BPSC Mains examiner. Evaluate the following essay on the topic "%s". Grade it strictly based on four pillars: Introduction, Fact-based Evidence (dates, names, articles), Structure/Flow, and Conclusion. Provide a score out of 10 for each category, an overall score, and 3 specific bullet points of constructive feedback.

Return ONLY a valid JSON object matching exactly this structure, with no additional markdown or formatting:
{
  "introduction_score": <int out of 10>,
  "fact_based_score": <int out of 10>,
  "structure_score": <int out of 10>,
  "conclusion_score": <int out of 10>,
  "overall_score": <int out of 10>,
  "feedback": ["point 1", "point 2", "point 3"]
}

Essay:
%s`, req.Topic, req.Essay)

	responseStr, err := h.llm.GenerateContent(r.Context(), prompt)
	if err != nil {
		log.Printf("[MainsEvaluationHandler] 🚨 LLM error: %v", err)
		writeError(w, "Essay evaluation is temporarily unavailable. Please try again.", http.StatusInternalServerError)
		return
	}

	// Clean up potential markdown formatting from Gemini
	cleanJSON := strings.TrimSpace(responseStr)
	if strings.HasPrefix(cleanJSON, "```") {
		lines := strings.Split(cleanJSON, "\n")
		if len(lines) > 0 && strings.HasPrefix(strings.TrimSpace(lines[0]), "```") {
			lines = lines[1:]
		}
		if len(lines) > 0 && strings.HasPrefix(strings.TrimSpace(lines[len(lines)-1]), "```") {
			lines = lines[:len(lines)-1]
		}
		cleanJSON = strings.Join(lines, "\n")
	}
	cleanJSON = strings.TrimSpace(cleanJSON)

	var evalResp models.MainsEvaluationResponse
	if err := json.Unmarshal([]byte(cleanJSON), &evalResp); err != nil {
		log.Printf("[MainsEvaluationHandler] Failed to parse LLM JSON: %v. Raw output: %s", err, cleanJSON)
		writeError(w, "Failed to parse evaluation response from AI", http.StatusInternalServerError)
		return
	}

	log.Printf("[MainsEvaluationHandler] ✅ Evaluation completed successfully")
	writeJSON(w, http.StatusOK, evalResp)
}
