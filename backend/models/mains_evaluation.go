package models

// MainsEvaluationRequest represents the payload for evaluating a Mains essay.
type MainsEvaluationRequest struct {
	Topic string `json:"topic"`
	Essay string `json:"essay"`
}

// MainsEvaluationResponse represents the structured feedback from the AI examiner.
type MainsEvaluationResponse struct {
	IntroductionScore int      `json:"introduction_score"`
	FactBasedScore    int      `json:"fact_based_score"`
	StructureScore    int      `json:"structure_score"`
	ConclusionScore   int      `json:"conclusion_score"`
	OverallScore      int      `json:"overall_score"`
	Feedback          []string `json:"feedback"`
}
