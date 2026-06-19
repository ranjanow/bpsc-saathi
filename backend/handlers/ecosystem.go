package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"

	"bpsc-engine/models"
	"bpsc-engine/repositories"
	"bpsc-engine/services"
)

// EcosystemHandler bundles the dependencies needed to serve the
// /api/v1/generate-ecosystem endpoint.  Construct it with NewEcosystemHandler.
type EcosystemHandler struct {
	llm  *services.LLMService
	repo *repositories.EcosystemRepository
}

// NewEcosystemHandler returns a ready-to-use EcosystemHandler.
// Both dependencies are required and must be non-nil.
func NewEcosystemHandler(llm *services.LLMService, repo *repositories.EcosystemRepository) *EcosystemHandler {
	return &EcosystemHandler{llm: llm, repo: repo}
}

// HandleGenerateEcosystem is the live AI-powered topic ecosystem generator.
//
// POST /api/v1/generate-ecosystem
//
// Accepts: models.EcosystemRequest  (JSON body)
// Returns: models.EcosystemResponse (JSON body) — also persisted to PostgreSQL
//
// Request defaults:
//
//	limit (volume): 10 questions when not specified or ≤ 0.
//
// HTTP status taxonomy:
//
//	200 OK          — full response, all N questions present (or within tolerance).
//	206 Partial     — truncation/volume event; questions were salvaged but fewer than requested.
//	                  Response body is a valid EcosystemResponse with whatever was recovered.
//	                  X-Retry-With-Volume header is set to a suggested lower value.
//	400 Bad Request — missing topic, invalid body.
//	500 Internal    — Gemini API error or total JSON parse failure with no salvageable data.
//	                  X-Retry-With-Volume is set to suggest retrying at lower volume.
//
// Flow:
//  1. Decode & validate request
//  2. Call Gemini via LLMService → EcosystemResponse
//  3. Inspect error type — handle volume shortfalls gracefully
//  4. Persist to PostgreSQL (non-fatal if DB write fails)
//  5. Return JSON
func (h *EcosystemHandler) HandleGenerateEcosystem(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, "Method not allowed. Use POST.", http.StatusMethodNotAllowed)
		return
	}

	// ── 1. Decode request body ────────────────────────────────────────────────
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MB limit
	defer r.Body.Close()

	var req models.EcosystemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
		return
	}

	if req.Topic == "" {
		writeError(w, "Field 'topic' is required", http.StatusBadRequest)
		return
	}

	// Default to 12 questions (3E+5M+4H) when the caller omits the limit.
	if req.Limit <= 0 {
		req.Limit = services.DefaultVolume
	}

	// ── 2. Call the LLM ───────────────────────────────────────────────────────
	log.Printf("[Handler] Generating ecosystem — topic=%q volume=%d difficulty=%q",
		req.Topic, req.Limit, req.Difficulty)

	ecosystem, err := h.llm.GenerateBPSCEcosystem(r.Context(), req.Topic, req.Limit, req.Difficulty, req.PyqStrictMode)

	// ── 3. Error classification ───────────────────────────────────────────────
	if err != nil {
		var volErr *services.EcosystemVolumeError
		if errors.As(err, &volErr) {
			// ── Volume shortfall: we have partial data ────────────────────────
			// The LLM returned fewer questions than requested.  If the ecosystem
			// pointer is non-nil, we salvaged some content.
			if ecosystem != nil && len(ecosystem.GeneratedQuestions) > 0 {
				suggestedVolume := suggestRetryVolume(req.Limit, volErr.Received)
				log.Printf("[Handler] ⚠️  Partial response: requested=%d received=%d — returning 206 with salvaged data (suggest retry at %d)",
					volErr.Requested, volErr.Received, suggestedVolume)

				w.Header().Set("X-Volume-Requested", fmt.Sprintf("%d", req.Limit))
				w.Header().Set("X-Volume-Received", fmt.Sprintf("%d", volErr.Received))
				w.Header().Set("X-Retry-With-Volume", fmt.Sprintf("%d", suggestedVolume))

				// 206 Partial Content signals "we got something useful, but not
				// everything you asked for."
				writeJSON(w, http.StatusPartialContent, ecosystem)
				return
			}

			// Volume error with no salvageable data → 500 + retry hint.
			suggestedVolume := suggestRetryVolume(req.Limit, 0)
			log.Printf("[Handler] 🚨 Volume error with zero salvaged questions for topic=%q. Returning 500 (suggest retry at %d).", req.Topic, suggestedVolume)
			w.Header().Set("X-Retry-With-Volume", fmt.Sprintf("%d", suggestedVolume))
			writeError(w,
				fmt.Sprintf("AI generation truncated with no recoverable data. Retry with 'limit': %d", suggestedVolume),
				http.StatusInternalServerError,
			)
			return
		}

		// Non-volume error (API call failure, total parse failure, etc.)
		log.Printf("[Handler] 🚨 LLM error for topic=%q: %v", req.Topic, err)
		suggestedVolume := suggestRetryVolume(req.Limit, 0)
		w.Header().Set("X-Retry-With-Volume", fmt.Sprintf("%d", suggestedVolume))
		writeError(w,
			fmt.Sprintf("AI generation failed. Consider retrying with 'limit': %d.", suggestedVolume),
			http.StatusInternalServerError,
		)
		return
	}

	// ── 4. Persist to PostgreSQL ──────────────────────────────────────────────
	ecosystemID, dbErr := h.repo.SaveEcosystem(r.Context(), ecosystem)
	if dbErr != nil {
		// Non-fatal: we still have a valid ecosystem from the LLM.
		log.Printf("[Handler] ⚠️  DB save failed (returning LLM result anyway): %v", dbErr)
	} else {
		log.Printf("[Handler] ✅ Ecosystem saved to DB id=%s", ecosystemID)
		w.Header().Set("X-Ecosystem-ID", ecosystemID)
	}

	// ── 5. Return response ────────────────────────────────────────────────────
	log.Printf("[Handler] ✅ Returning %d questions for topic=%q",
		len(ecosystem.GeneratedQuestions), req.Topic)
	writeJSON(w, http.StatusOK, ecosystem)
}

// ─────────────────────────────────────────────────────────────────────────────
// suggestRetryVolume calculates a conservative volume for the client to use
// on a retry after a truncation event.
//
// Strategy:
//   - If the LLM actually returned something (received > 0), suggest 80% of
//     what was received to give a comfortable token-budget buffer.
//   - If received == 0 (total failure), halve the original limit.
//   - Always clamp to [services.MinVolume, services.MaxVolume].
//
// ─────────────────────────────────────────────────────────────────────────────
func suggestRetryVolume(requested, received int) int {
	var suggested int
	if received > 0 {
		// 80% of what the LLM actually managed to produce.
		suggested = int(float64(received) * 0.8)
	} else {
		// Blind halving when we have no baseline.
		suggested = requested / 2
	}

	if suggested < services.MinVolume {
		suggested = services.MinVolume
	}
	if suggested > services.MaxVolume {
		suggested = services.MaxVolume
	}
	return suggested
}

// coalesce returns the first non-empty string from the arguments.
func coalesce(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
