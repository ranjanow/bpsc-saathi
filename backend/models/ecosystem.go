package models

// GeneratedQuestion represents a single AI-generated examination question
// with its metadata, options, and explanation.
type GeneratedQuestion struct {
	ID                 string   `json:"id"`
	QuestionEN         string   `json:"question_en"`
	QuestionHI         string   `json:"question_hi"`
	OptionsEN          []string `json:"options_en"`
	OptionsHI          []string `json:"options_hi"`
	CorrectOptionIndex int      `json:"correctOptionIndex"`
	ExplanationEN      string   `json:"explanation_en"`
	ExplanationHI      string   `json:"explanation_hi"`
	Difficulty         string   `json:"difficulty"` // "easy", "medium", "hard"
	Subject            string   `json:"subject"`
	PyqYear            string   `json:"pyqYear,omitempty"` // e.g. "BPSC 67th 2022", "" if original
}

// EcosystemResponse is the primary AI output schema.
// It maps a core topic to its connected static concepts and generates
// predictive examination questions based on the topic ecosystem.
type EcosystemResponse struct {
	CoreTopic               string              `json:"coreTopic"`
	ConnectedStaticConcepts []string            `json:"connectedStaticConcepts"`
	GeneratedQuestions      []GeneratedQuestion `json:"generatedQuestions"`
}

// EcosystemRequest is the input payload for the /api/v1/generate-ecosystem endpoint.
type EcosystemRequest struct {
	Topic         string `json:"topic"`
	Difficulty    string `json:"difficulty,omitempty"` // optional filter: "easy", "medium", "hard"
	Limit         int    `json:"limit,omitempty"`      // optional: max number of questions to generate
	PyqStrictMode bool   `json:"pyq_strict_mode,omitempty"`
}

// ErrorResponse provides a standardized error payload for all API errors.
type ErrorResponse struct {
	Error   string `json:"error"`
	Code    int    `json:"code"`
	Details string `json:"details,omitempty"`
}

// HealthResponse is returned by the /ping health-check endpoint.
type HealthResponse struct {
	Status    string `json:"status"`
	Service   string `json:"service"`
	Version   string `json:"version"`
	Timestamp string `json:"timestamp"`
}
