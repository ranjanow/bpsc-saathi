package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"bpsc-engine/repositories"
	"bpsc-engine/services"
)

// ─────────────────────────────────────────────────────────────────────────────
// StudyPlannerHandler — Feature 8: AI-Powered Study Planner
// ─────────────────────────────────────────────────────────────────────────────

type StudyPlannerHandler struct {
	repo *repositories.FeaturesRepository
	llm  *services.LLMService
}

func NewStudyPlannerHandler(repo *repositories.FeaturesRepository, llm *services.LLMService) *StudyPlannerHandler {
	return &StudyPlannerHandler{repo: repo, llm: llm}
}

// HandleGetPlan returns GET /api/v1/study-plan
func (h *StudyPlannerHandler) HandleGetPlan(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	plan, err := h.repo.GetActivePlan(claims.UserID)
	if err != nil {
		jsonError(w, "failed to get plan", http.StatusInternalServerError)
		return
	}
	if plan == nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{"plan": nil, "hasPlan": false})
		return
	}

	tasks, _ := h.repo.GetTodayTasks(claims.UserID)
	if tasks == nil {
		tasks = []repositories.StudyTask{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"plan":       plan,
		"hasPlan":    true,
		"todayTasks": tasks,
	})
}

// HandleCreatePlan handles POST /api/v1/study-plan
func (h *StudyPlannerHandler) HandleCreatePlan(w http.ResponseWriter, r *http.Request) {
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
		ExamDate         *string  `json:"examDate"`
		TargetHoursPerDay float64 `json:"targetHoursPerDay"`
		Subjects         []string `json:"subjects"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if req.TargetHoursPerDay <= 0 {
		req.TargetHoursPerDay = 4.0
	}
	if len(req.Subjects) == 0 {
		req.Subjects = []string{"History", "Geography", "Polity", "Economics", "Science", "Current Affairs"}
	}

	subjectsJSON, _ := json.Marshal(req.Subjects)

	plan, err := h.repo.CreateStudyPlan(claims.UserID, req.ExamDate, req.TargetHoursPerDay, subjectsJSON)
	if err != nil {
		log.Printf("[StudyPlan] ❌ Error: %v", err)
		jsonError(w, "failed to create plan", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(plan)
}

// HandleCompleteTask handles POST /api/v1/study-plan/complete-task
func (h *StudyPlannerHandler) HandleCompleteTask(w http.ResponseWriter, r *http.Request) {
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
		TaskID string `json:"taskId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	if err := h.repo.CompleteTask(req.TaskID, claims.UserID); err != nil {
		jsonError(w, "failed to complete task", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "task completed"})
}

// ─────────────────────────────────────────────────────────────────────────────
// NotesHandler — Feature 9: Bookmark Vault / Saved Notes
// ─────────────────────────────────────────────────────────────────────────────

type NotesHandler struct {
	repo *repositories.FeaturesRepository
}

func NewNotesHandler(repo *repositories.FeaturesRepository) *NotesHandler {
	return &NotesHandler{repo: repo}
}

// HandleNotes handles GET/POST/DELETE /api/v1/notes
func (h *NotesHandler) HandleNotes(w http.ResponseWriter, r *http.Request) {
	claims := GetUserFromContext(r.Context())
	if claims == nil {
		jsonError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	switch r.Method {
	case http.MethodGet:
		notes, err := h.repo.GetNotes(claims.UserID, 50)
		if err != nil {
			jsonError(w, "failed to get notes", http.StatusInternalServerError)
			return
		}
		if notes == nil {
			notes = []repositories.SavedNote{}
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{"notes": notes})

	case http.MethodPost:
		var req struct {
			Title    string   `json:"title"`
			Content  string   `json:"content"`
			NoteType string   `json:"noteType"`
			Subject  string   `json:"subject"`
			Topic    string   `json:"topic"`
			SourceID string   `json:"sourceId"`
			Tags     []string `json:"tags"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonError(w, "invalid JSON", http.StatusBadRequest)
			return
		}
		if req.Title == "" || req.Content == "" {
			jsonError(w, "title and content required", http.StatusBadRequest)
			return
		}
		if req.NoteType == "" {
			req.NoteType = "note"
		}

		tagsJSON, _ := json.Marshal(req.Tags)

		note, err := h.repo.CreateNote(claims.UserID, req.Title, req.Content, req.NoteType,
			req.Subject, req.Topic, req.SourceID, tagsJSON)
		if err != nil {
			jsonError(w, "failed to save note", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(note)

	case http.MethodDelete:
		id := r.URL.Query().Get("id")
		if id == "" {
			jsonError(w, "id required", http.StatusBadRequest)
			return
		}
		if err := h.repo.DeleteNote(id, claims.UserID); err != nil {
			jsonError(w, "failed to delete note", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "note deleted"})

	default:
		jsonError(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}
