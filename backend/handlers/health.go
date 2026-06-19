package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"bpsc-engine/models"
)

const (
	ServiceName    = "bpsc-engine"
	ServiceVersion = "0.1.0"
)

// HandlePing is the health-check endpoint.
// GET /ping
// Returns service status, version, and current timestamp.
func HandlePing(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	resp := models.HealthResponse{
		Status:    "ok",
		Service:   ServiceName,
		Version:   ServiceVersion,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}

	writeJSON(w, http.StatusOK, resp)
}

// writeJSON encodes a value as JSON and writes it to the response.
func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("[writeJSON] encoding error (headers already sent): %v", err)
	}
}

// writeError writes a standardized error response.
func writeError(w http.ResponseWriter, message string, code int) {
	resp := models.ErrorResponse{
		Error: message,
		Code:  code,
	}
	writeJSON(w, code, resp)
}
