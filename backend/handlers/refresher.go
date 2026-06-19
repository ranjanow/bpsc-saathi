package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
)

type RefresherHandler struct {
	llm LLMService
}

func NewRefresherHandler(llm LLMService) *RefresherHandler {
	return &RefresherHandler{llm: llm}
}

func (h *RefresherHandler) HandleGetSyllabusRefresher(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, "Method not allowed. Use GET.", http.StatusMethodNotAllowed)
		return
	}

	topic := r.URL.Query().Get("topic")
	if topic == "" {
		writeError(w, "Topic is required", http.StatusBadRequest)
		return
	}
	if len(topic) > 200 {
		writeError(w, "Topic must be 200 characters or fewer", http.StatusBadRequest)
		return
	}

	prompt := fmt.Sprintf(`Act as a BPSC history professor. 
    Provide a 200-word, high-yield summary of "%s" suitable for the BPSC Prelims exam. 
    Include only the most important dates, names, and key events in a clear bulleted format.`, topic)

	summary, err := h.llm.GenerateContent(r.Context(), prompt)
	if err != nil {
		log.Printf("[RefresherHandler] 🚨 LLM error: %v", err)
		writeError(w, "Failed to generate summary. Please try again.", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"topic":   topic,
		"summary": summary,
	})
}
