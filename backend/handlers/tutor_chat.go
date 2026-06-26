package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"bpsc-engine/repositories"
	"bpsc-engine/services"
)

// ─────────────────────────────────────────────────────────────────────────────
// TutorChatHandler — Persistent AI Tutor + Mentor chat with memory
// Features 4 & 5: AI Tutor (USP) + AI Mentor
// ─────────────────────────────────────────────────────────────────────────────

type TutorChatHandler struct {
	llm  *services.LLMService
	repo *repositories.FeaturesRepository
}

func NewTutorChatHandler(llm *services.LLMService, repo *repositories.FeaturesRepository) *TutorChatHandler {
	return &TutorChatHandler{llm: llm, repo: repo}
}

// HandleListSessions returns GET /api/v1/tutor-chat/sessions
func (h *TutorChatHandler) HandleListSessions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	sessions, err := h.repo.GetUserChatSessions(claims.UserID, 20)
	if err != nil {
		jsonError(w, "failed to get sessions", http.StatusInternalServerError)
		return
	}
	if sessions == nil {
		sessions = []repositories.ChatSession{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"sessions": sessions})
}

// HandleCreateSession handles POST /api/v1/tutor-chat/sessions
func (h *TutorChatHandler) HandleCreateSession(w http.ResponseWriter, r *http.Request) {
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
		SessionType string `json:"sessionType"` // 'tutor' or 'mentor'
		Title       string `json:"title"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if req.SessionType == "" {
		req.SessionType = "tutor"
	}
	if req.Title == "" {
		req.Title = "New Chat"
	}

	session, err := h.repo.CreateChatSession(claims.UserID, req.SessionType, req.Title)
	if err != nil {
		jsonError(w, "failed to create session", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(session)
}

// HandleGetMessages returns GET /api/v1/tutor-chat/messages?sessionId=xxx
func (h *TutorChatHandler) HandleGetMessages(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	sessionID := r.URL.Query().Get("sessionId")
	if sessionID == "" {
		jsonError(w, "sessionId required", http.StatusBadRequest)
		return
	}

	messages, err := h.repo.GetChatMessages(sessionID, 50)
	if err != nil {
		jsonError(w, "failed to get messages", http.StatusInternalServerError)
		return
	}
	if messages == nil {
		messages = []repositories.ChatMessage{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"messages": messages})
}

// HandleSendMessage handles POST /api/v1/tutor-chat/send
func (h *TutorChatHandler) HandleSendMessage(w http.ResponseWriter, r *http.Request) {
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
		SessionID   string `json:"sessionId"`
		Message     string `json:"message"`
		SessionType string `json:"sessionType"` // tutor or mentor
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if req.SessionID == "" || req.Message == "" {
		jsonError(w, "sessionId and message required", http.StatusBadRequest)
		return
	}
	if req.SessionType == "" {
		req.SessionType = "tutor"
	}

	// Save user message
	_, err := h.repo.AddChatMessage(req.SessionID, "user", req.Message, nil)
	if err != nil {
		jsonError(w, "failed to save message", http.StatusInternalServerError)
		return
	}

	// Get conversation history for context
	history, _ := h.repo.GetChatMessages(req.SessionID, 20)
	var contextParts []string
	for _, m := range history {
		prefix := "Student"
		if m.Role == "assistant" {
			prefix = "Tutor"
		}
		contextParts = append(contextParts, prefix+": "+m.Content)
	}
	conversationContext := strings.Join(contextParts, "\n")

	// Build prompt based on session type
	var systemPrompt string
	if req.SessionType == "mentor" {
		systemPrompt = `You are BPSC Saathi Mentor — an experienced, empathetic career mentor specializing in BPSC exam preparation.
Your role: Provide motivational guidance, study strategy advice, time management tips, and emotional support.
You understand the Bihar Public Service Commission exam deeply. Give practical, actionable advice.
Be warm, supportive, and encouraging. Use Hindi terms where appropriate.
Respond in the student's language (Hindi or English).`
	} else {
		systemPrompt = `You are BPSC Saathi AI Tutor — an expert professor for BPSC exam subjects.
Your role: Explain concepts clearly, solve doubts, provide examples, and connect topics to BPSC PYQ patterns.
Subjects: Indian History, Bihar History, Geography, Indian Polity, Economics, Science, Current Affairs.
Be thorough but concise. Use analogies. Reference BPSC exam patterns.
Respond in the student's language (Hindi or English). Format with bullet points when helpful.`
	}

	// Call LLM
	fullPrompt := systemPrompt + "\n\n--- Conversation History ---\n" + conversationContext + "\n\nRespond to the student's latest message."
	aiReply, err := h.llm.GenerateText(fullPrompt)
	if err != nil {
		log.Printf("[TutorChat] ❌ LLM error: %v", err)
		aiReply = "I'm having trouble responding right now. Please try again in a moment."
	}

	// Save AI response
	savedMsg, _ := h.repo.AddChatMessage(req.SessionID, "assistant", aiReply, nil)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(savedMsg)
}
