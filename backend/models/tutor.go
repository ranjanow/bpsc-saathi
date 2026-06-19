package models

// TutorRequest represents the payload from the client asking a follow-up question.
type TutorRequest struct {
	QuestionText        string `json:"question_text"`
	CorrectAnswer       string `json:"correct_answer"`
	OriginalExplanation string `json:"original_explanation"`
	DoubtQuery          string `json:"doubt_query"`
}

// TutorResponse is the structured reply from the AI tutor.
type TutorResponse struct {
	Response string `json:"response"`
}
