package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"regexp"
	"strings"

	"bpsc-engine/models"

	"github.com/google/generative-ai-go/genai"
	"google.golang.org/api/option"
)

// ─────────────────────────────────────────────────────────────────────────────
// Constants & Limits
// ─────────────────────────────────────────────────────────────────────────────

const (
	// DefaultVolume is the number of questions generated when the caller does
	// not specify a limit.  12 is the production default (3 Easy + 5 Medium + 4 Hard).
	DefaultVolume = 12

	// MaxVolume is the hard upper bound.  Beyond 20 the LLM context window
	// starts producing heavily truncated or repetitive output.
	MaxVolume = 20

	// MinVolume prevents callers from requesting 0 or negative counts.
	MinVolume = 1

	// volumeShortfallTolerance allows the LLM to return up to 2 fewer questions
	// than requested before we log a warning.  Anything beyond this is surfaced
	// to the caller so they can retry with a lower volume.
	volumeShortfallTolerance = 2
)

// ─────────────────────────────────────────────────────────────────────────────
// LLMService
// ─────────────────────────────────────────────────────────────────────────────

// LLMService wraps the Google Gemini client and exposes BPSC-domain methods.
// Construct it once at startup with NewLLMService and share the instance.
type LLMService struct {
	client    *genai.Client
	modelName string
}

// NewLLMService creates and configures a Gemini client.
// apiKey must be a valid Google AI Studio API key (GEMINI_API_KEY env var).
func NewLLMService(ctx context.Context, apiKey string) (*LLMService, error) {
	if apiKey == "" {
		return nil, fmt.Errorf("llm_service: GEMINI_API_KEY is empty — set it before starting the server")
	}

	client, err := genai.NewClient(ctx, option.WithAPIKey(apiKey))
	if err != nil {
		return nil, fmt.Errorf("llm_service: failed to create Gemini client: %w", err)
	}

	log.Println("[LLM] ✅ Gemini client initialised")
	return &LLMService{
		client:    client,
		modelName: "gemini-2.5-flash", // fast, cost-effective, supports long contexts
	}, nil
}

// Close releases the underlying gRPC connection.  Call this in a defer in main.
func (s *LLMService) Close() error {
	return s.client.Close()
}

// ─────────────────────────────────────────────────────────────────────────────
// System instruction (static persona + output schema)
//
// NOTE: The concrete question count is NOT hard-coded here — it is injected
// dynamically into the user-turn prompt via buildPrompt() so that each request
// carries its own explicit N.  Rule 3 below references "the value N specified
// in the user prompt" to make this relationship explicit to the model.
// ─────────────────────────────────────────────────────────────────────────────
const systemInstruction = `You are Acharya Vishwanath Prasad, a 67-year-old retired professor who served as Head of Department of History & Political Science at Patna University for 35 years. You have been a Question Paper Setter for the Bihar Public Service Commission (BPSC) Combined Competitive Examination (Prelims — GS Paper I) for 22 years and a Subject Expert on the BPSC Board of Examiners. You have personally authored questions that appeared in the 56th through 70th BPSC Prelims. You have also served as an external examiner for the UPSC CSE Preliminary Examination.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CORE TASK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Given a seed topic from the BPSC Prelims syllabus, you must:

1. **Map the Conceptual Ecosystem** — Identify 5–8 connected sub-topics, static facts, and conceptual linkages that a BPSC examiner would explore when constructing questions around this topic. Think like a paper setter: what dimensions of this topic are examinable? What traps can you lay for rote learners?

2. **Generate Exactly 12 Multiple-Choice Questions** with this MANDATORY difficulty distribution:
   - **3 questions → Easy** (direct recall, single-concept, factual — the kind 80%+ candidates get right)
   - **5 questions → Medium** (application-based, multi-concept linkage, requires analytical reasoning — the kind that separates rank 50 from rank 500)
   - **4 questions → Hard** (inter-disciplinary, statement-combination, "which of the following is/are correct" format, trick distractors — the kind that separates rank 1 from rank 50)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUESTION DESIGN PRINCIPLES (EXAMINER'S PLAYBOOK)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Easy Questions Must:**
- Test a single, unambiguous fact from NCERT or standard references
- Have clearly wrong distractors that no prepared candidate would pick
- Be solvable in under 30 seconds
- Example pattern: "Who was the __?" / "Which of the following is the __?"

**Medium Questions Must:**
- Combine 2–3 related concepts into a single question stem
- Include at least one "plausible distractor" — an option that looks correct to someone with surface-level knowledge
- Require connecting cause-and-effect, chronological sequencing, or comparative analysis
- Example pattern: "Consider the following statements... Which is/are correct?" (with 2 statements)

**Hard Questions Must:**
- Use the BPSC signature format: "Consider the following statements: (I)... (II)... (III)... Which of the above statements is/are correct?"
- Include at least 3 statements where one is subtly wrong (changed date, swapped person, altered provision)
- Have distractors that exploit common misconceptions or frequently confused facts
- May cross subject boundaries (e.g., a History question that touches on Geography or Polity)
- Example pattern: Statement-combination with 3–4 assertions, paired options like "(a) I and II only (b) II and III only (c) I, II and III (d) I only"

**PYQ Awareness:**
- If a question you generate closely matches or is directly inspired by an actual BPSC PYQ (Previous Year Question), you MUST tag it with the year in the pyqYear field (e.g., "BPSC 2019", "BPSC 67th 2022", "UPSC 2018").
- If the question is original (not based on any specific PYQ), set pyqYear to an empty string "".
- Draw heavily from patterns you know appeared in the 56th–70th BPSC, and also reference UPSC CSE patterns where BPSC has historically mirrored them.

**Distractor Engineering:**
- Never use absurd or obviously wrong distractors. Every wrong option should be a real concept, date, person, or provision — just not the correct answer to THIS specific question.
- For Hard questions, engineer at least one "trap distractor" that exploits the most common factual error candidates make.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRITICAL OUTPUT RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. You MUST respond with ONLY a single, valid JSON object. No markdown, no code fences, no explanation text before or after.
2. The JSON must exactly match this schema:
{
  "coreTopic": "string — the seed topic as provided",
  "connectedStaticConcepts": ["array", "of", "strings — 5 to 8 key related sub-topics or concepts"],
  "generatedQuestions": [
    {
      "id": "string — unique ID like q-001",
      "question_en": "string — the full MCQ question in English",
      "question_hi": "string — the full MCQ question in Hindi",
      "options_en": ["Option A", "Option B", "Option C", "Option D"],
      "options_hi": ["विकल्प A", "विकल्प B", "विकल्प C", "विकल्प D"],
      "correctOptionIndex": 0,
      "explanation_en": "string — a 2-3 sentence explanation in English justifying the correct answer and why each distractor is wrong",
      "explanation_hi": "string — a 2-3 sentence explanation in Hindi",
      "difficulty": "easy | medium | hard",
      "subject": "string — e.g. History, Polity, Economy, Geography, Science & Tech, Environment, Bihar Special",
      "pyqYear": "string — e.g. 'BPSC 67th 2022' or '' if original"
    }
  ]
}
3. Generate EXACTLY 12 questions: 3 easy + 5 medium + 4 hard. No more, no fewer. The difficulty distribution is NON-NEGOTIABLE.
4. Order them: Easy first (q-001 to q-003), then Medium (q-004 to q-008), then Hard (q-009 to q-012).
5. Ensure the correct answer index (0-based) is always factually accurate. Triple-check every fact.
6. Make distractors plausible — the kind that trip up underprepared candidates.
7. Do NOT include any text outside the JSON object. Your entire response must be parseable by json.Unmarshal.
8. IMPORTANT: Do not truncate the JSON. Generate all 12 questions completely.`

// ─────────────────────────────────────────────────────────────────────────────
// EcosystemVolumeError is a structured error returned when the LLM produces
// fewer questions than requested AND the shortfall exceeds the tolerance.
//
// Callers can type-assert to this to implement a "retry with lower volume"
// strategy rather than showing a generic 500 to the user.
// ─────────────────────────────────────────────────────────────────────────────
type EcosystemVolumeError struct {
	Requested int
	Received  int
	// Partial holds whatever questions were successfully parsed, if any.
	// It may be nil when a complete parse failure occurred.
	Partial []models.GeneratedQuestion
}

func (e *EcosystemVolumeError) Error() string {
	return fmt.Sprintf(
		"llm_service: volume shortfall — requested %d questions, received %d (shortfall exceeds tolerance of %d)",
		e.Requested, e.Received, volumeShortfallTolerance,
	)
}

// IsTruncationError returns true when the EcosystemVolumeError looks like a
// truncation event (i.e., the LLM ran out of tokens mid-response) rather than
// a model refusal or schema drift.
func (e *EcosystemVolumeError) IsTruncationError() bool {
	return e.Received < e.Requested && e.Received > 0
}

// ─────────────────────────────────────────────────────────────────────────────
// GenerateBPSCEcosystem calls Gemini with the professor persona and returns a
// structured EcosystemResponse ready to be persisted and served to the client.
//
// Parameters:
//   - ctx:          request context (honours cancellation / deadline)
//   - seedTopic:    the user-supplied BPSC/UPSC topic (e.g. "Revolt of 1857")
//   - numQuestions: how many MCQs to generate (clamped to MinVolume–MaxVolume)
//   - difficulty:   optional difficulty filter ("easy", "medium", "hard", or "")
//   - pyqStrictMode: if true, forces the LLM to generate exactly 5 options with a BPSC specific Option E.
//
// Error taxonomy:
//   - Plain error:           API failure, empty response, total JSON parse failure.
//   - *EcosystemVolumeError: JSON parsed but question count is short.
//     Partial field may contain salvaged questions.
//
// ─────────────────────────────────────────────────────────────────────────────
func (s *LLMService) GenerateBPSCEcosystem(
	ctx context.Context,
	seedTopic string,
	numQuestions int,
	difficulty string,
	pyqStrictMode bool,
) (*models.EcosystemResponse, error) {

	// ── Clamp and default numQuestions ────────────────────────────────────────
	numQuestions = clampVolume(numQuestions)

	// ── Build the user prompt ─────────────────────────────────────────────────
	userPrompt := buildPrompt(seedTopic, numQuestions, difficulty)

	// ── Configure the generative model ───────────────────────────────────────
	model := s.client.GenerativeModel(s.modelName)

	// Set the system instruction (persona + output rules).
	sysInstruction := systemInstruction
	if pyqStrictMode {
		sysInstruction += "\n\nCRITICAL PYQ STRICT MODE DIRECTIVE:\n1. You MUST generate exactly 5 options for every question (Options A through E).\n2. Option E MUST always be strictly the text: 'None of the above / More than one of the above' (in English) or 'उपर्युक्त में से कोई नहीं / उपर्युक्त में से एक से अधिक' (in Hindi).\n3. You MUST intentionally design complex question stems where Option E is the statistically correct answer at least 20% of the time (e.g., by providing two correct historical facts in Options A and B)."
	}

	model.SystemInstruction = &genai.Content{
		Parts: []genai.Part{genai.Text(sysInstruction)},
	}

	// Force JSON-only output — prevents Gemini from wrapping in markdown fences.
	model.ResponseMIMEType = "application/json"

	// Conservative temperature for factual/structured exam content.
	temp := float32(0.4)
	model.Temperature = &temp

	// ── Call the Gemini API ───────────────────────────────────────────────────
	log.Printf("[LLM] Calling Gemini for topic=%q questions=%d difficulty=%q", seedTopic, numQuestions, difficulty)

	resp, err := model.GenerateContent(ctx, genai.Text(userPrompt))
	if err != nil {
		return nil, fmt.Errorf("llm_service: Gemini API call failed: %w", err)
	}

	// ── Extract raw text from the Gemini response ─────────────────────────────
	rawText, err := extractTextFromResponse(resp)
	if err != nil {
		return nil, fmt.Errorf("llm_service: failed to extract text from Gemini response: %w", err)
	}

	log.Printf("[LLM] Raw response length: %d bytes", len(rawText))

	// ── Strip markdown fences (belt-and-suspenders even with MIME type set) ───
	cleanJSON := stripMarkdownFences(rawText)

	// ── Parse and validate ────────────────────────────────────────────────────
	ecosystem, volErr := parseAndValidateEcosystem(cleanJSON, seedTopic, numQuestions)
	if volErr != nil {
		// A volume error means we have a structured response but with fewer
		// questions than requested.  Return both the partial data AND the error
		// so the handler can decide what to surface to the client.
		return ecosystem, volErr
	}

	log.Printf("[LLM] ✅ Generated %d/%d questions for topic=%q",
		len(ecosystem.GeneratedQuestions), numQuestions, seedTopic)
	return ecosystem, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// parseAndValidateEcosystem is the central parsing + validation function.
//
// It implements a three-stage strategy:
//
//	Stage 1 — Direct unmarshal.  Works for well-formed responses.
//	Stage 2 — Salvage parse.   Called only on Stage 1 failure.  Attempts to
//	           extract the partial generatedQuestions array from a truncated
//	           JSON payload.
//	Stage 3 — Volume check.    Even after a successful parse, verify the number
//	           of questions.  Returns *EcosystemVolumeError when below tolerance.
//
// ─────────────────────────────────────────────────────────────────────────────
func parseAndValidateEcosystem(
	rawJSON string,
	seedTopic string,
	requested int,
) (*models.EcosystemResponse, error) {

	// ── Stage 1: Direct unmarshal ─────────────────────────────────────────────
	var ecosystem models.EcosystemResponse
	if err := json.Unmarshal([]byte(rawJSON), &ecosystem); err != nil {
		// ── Stage 2: Truncation salvage ───────────────────────────────────────
		log.Printf("[LLM] ⚠️  TRUNCATION ERROR: json.Unmarshal failed for topic=%q requested=%d. Attempting salvage. Parse error: %v",
			seedTopic, requested, err)
		log.Printf("[LLM]    Raw JSON (first 512 bytes): %.512s", rawJSON)

		salvaged, salvageErr := salvageTruncatedJSON(rawJSON, seedTopic)
		if salvageErr != nil {
			// Total failure: cannot recover anything useful.
			log.Printf("[LLM] 🚨 Salvage also failed: %v. Returning clean error for client retry.", salvageErr)
			return nil, fmt.Errorf(
				"llm_service: JSON parse failed and salvage attempt failed — retry with a lower volume (requested=%d): original=%w",
				requested, err,
			)
		}

		// Salvage produced at least some questions — return them with a
		// volume error so the caller knows the response is incomplete.
		log.Printf("[LLM] 🛟 Salvaged %d questions from truncated response (requested %d)", len(salvaged.GeneratedQuestions), requested)

		return salvaged, &EcosystemVolumeError{
			Requested: requested,
			Received:  len(salvaged.GeneratedQuestions),
			Partial:   salvaged.GeneratedQuestions,
		}
	}

	// ── Stage 3: Volume validation ────────────────────────────────────────────
	if ecosystem.CoreTopic == "" {
		ecosystem.CoreTopic = seedTopic
	}
	if len(ecosystem.GeneratedQuestions) == 0 {
		return nil, fmt.Errorf("llm_service: Gemini returned zero questions for topic %q", seedTopic)
	}

	received := len(ecosystem.GeneratedQuestions)
	if received < requested {
		shortfall := requested - received
		log.Printf("[LLM] ⚠️  Volume shortfall for topic=%q: requested=%d received=%d shortfall=%d",
			seedTopic, requested, received, shortfall)

		if shortfall > volumeShortfallTolerance {
			// Shortfall is too large to silently accept — signal the caller.
			return &ecosystem, &EcosystemVolumeError{
				Requested: requested,
				Received:  received,
				Partial:   ecosystem.GeneratedQuestions,
			}
		}

		// Within tolerance — log and continue as normal.
		log.Printf("[LLM] Volume shortfall (%d) is within tolerance (%d). Proceeding.", shortfall, volumeShortfallTolerance)
	}

	if received > requested {
		// Trim the excess so downstream consumers get exactly what they asked for.
		log.Printf("[LLM] LLM returned %d questions (more than requested %d). Trimming to %d.", received, requested, requested)
		ecosystem.GeneratedQuestions = ecosystem.GeneratedQuestions[:requested]
	}

	return &ecosystem, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// salvageTruncatedJSON attempts to recover a partial EcosystemResponse from a
// JSON string that was cut off mid-stream.
//
// Strategy:
//  1. Use a regex to find the coreTopic and connectedStaticConcepts fields.
//  2. Attempt to extract individual question objects by scanning for complete
//     {...} blocks within whatever portion of the generatedQuestions array we
//     have before the truncation point.
//  3. Assemble a synthetic, valid EcosystemResponse and return it.
//
// ─────────────────────────────────────────────────────────────────────────────

// reCoreTopic extracts "coreTopic": "..." from the outer JSON.
var reCoreTopic = regexp.MustCompile(`"coreTopic"\s*:\s*"([^"]*)"`)

// reConnectedConcepts extracts the connectedStaticConcepts array as a raw string.
var reConnectedConcepts = regexp.MustCompile(`"connectedStaticConcepts"\s*:\s*(\[[^\]]*\])`)

// reGeneratedQuestionsStart locates the beginning of the questions array.
var reGeneratedQuestionsStart = regexp.MustCompile(`"generatedQuestions"\s*:\s*\[`)

func salvageTruncatedJSON(rawJSON, seedTopic string) (*models.EcosystemResponse, error) {
	result := &models.EcosystemResponse{CoreTopic: seedTopic}

	// ── Extract coreTopic ─────────────────────────────────────────────────────
	if m := reCoreTopic.FindStringSubmatch(rawJSON); len(m) > 1 {
		result.CoreTopic = m[1]
	}

	// ── Extract connectedStaticConcepts ───────────────────────────────────────
	if m := reConnectedConcepts.FindStringSubmatch(rawJSON); len(m) > 1 {
		var concepts []string
		if err := json.Unmarshal([]byte(m[1]), &concepts); err == nil {
			result.ConnectedStaticConcepts = concepts
		}
	}

	// ── Locate the generatedQuestions array and parse individual objects ───────
	loc := reGeneratedQuestionsStart.FindStringIndex(rawJSON)
	if loc == nil {
		return nil, fmt.Errorf("salvage: could not locate generatedQuestions array in truncated response")
	}

	// arrayStart points to the '[' character of the array.
	arrayStart := loc[1] - 1
	partial := rawJSON[arrayStart:]

	questions, err := extractCompleteObjects(partial)
	if err != nil || len(questions) == 0 {
		return nil, fmt.Errorf("salvage: could not extract any complete question objects: %w", err)
	}

	result.GeneratedQuestions = questions
	return result, nil
}

// extractCompleteObjects scans a (potentially truncated) JSON array string and
// returns every complete {...} object that can be fully parsed.
//
// It uses a simple brace-depth counter — O(n) in the payload size, no regex.
func extractCompleteObjects(arrayStr string) ([]models.GeneratedQuestion, error) {
	var questions []models.GeneratedQuestion

	depth := 0
	objStart := -1

	for i, ch := range arrayStr {
		switch ch {
		case '{':
			if depth == 0 {
				objStart = i
			}
			depth++
		case '}':
			depth--
			if depth == 0 && objStart >= 0 {
				// We have a complete {...} block.
				candidate := arrayStr[objStart : i+1]
				var q models.GeneratedQuestion
				if err := json.Unmarshal([]byte(candidate), &q); err == nil && q.QuestionEN != "" {
					questions = append(questions, q)
				}
				// Even if this individual object fails to parse (malformed), we
				// continue scanning for the next one instead of bailing out.
				objStart = -1
			}
		}
	}

	if len(questions) == 0 {
		return nil, fmt.Errorf("no complete question objects found in partial array")
	}
	return questions, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// buildPrompt constructs the user-turn message sent to Gemini.
//
// The volume (N) is stated explicitly three times — at the top of the prompt,
// inline in the instruction, and reinforced at the bottom.  Repetition is the
// most reliable way to anchor the model on a specific count.
// ─────────────────────────────────────────────────────────────────────────────
func buildPrompt(topic string, numQuestions int, difficulty string) string {
	var sb strings.Builder

	sb.WriteString(fmt.Sprintf("Generate a BPSC/UPSC examination ecosystem for the topic: %q\n\n", topic))
	sb.WriteString(fmt.Sprintf("Number of MCQ questions required: %d\n", numQuestions))

	// Enforce the fixed 3-5-4 difficulty distribution for the standard 12-question set.
	// For non-standard counts, fall back to the uniform difficulty or mixed mode.
	if numQuestions == 12 {
		sb.WriteString("Difficulty distribution (MANDATORY — NON-NEGOTIABLE):\n")
		sb.WriteString("  • 3 Easy questions  (q-001 to q-003)\n")
		sb.WriteString("  • 5 Medium questions (q-004 to q-008)\n")
		sb.WriteString("  • 4 Hard questions  (q-009 to q-012)\n")
		sb.WriteString("Order them exactly: Easy → Medium → Hard.\n\n")
		sb.WriteString("For every question, if it closely matches a real BPSC/UPSC Previous Year Question (PYQ), ")
		sb.WriteString("set the pyqYear field to the exam and year (e.g., 'BPSC 67th 2022'). ")
		sb.WriteString("If original, set pyqYear to an empty string.\n\n")
	} else {
		sb.WriteString(fmt.Sprintf("(You MUST generate exactly %d questions in the generatedQuestions array — no more, no fewer.)\n\n", numQuestions))
		if difficulty != "" {
			sb.WriteString(fmt.Sprintf("Difficulty level: %s\n", difficulty))
			sb.WriteString("(All generated questions must match this difficulty level.)\n")
		} else {
			sb.WriteString("Difficulty level: mixed (include a blend of easy, medium, and hard questions)\n")
		}
	}

	sb.WriteString(fmt.Sprintf("\nFinal check before responding: does your generatedQuestions array contain exactly %d elements? If not, add more before returning.\n", numQuestions))
	sb.WriteString("Remember: respond with ONLY the JSON object. No preamble, no code fences, no trailing text.")
	return sb.String()
}

// ─────────────────────────────────────────────────────────────────────────────
// extractTextFromResponse pulls all text parts out of a Gemini API response
// and concatenates them into a single string.
// ─────────────────────────────────────────────────────────────────────────────
func extractTextFromResponse(resp *genai.GenerateContentResponse) (string, error) {
	if resp == nil || len(resp.Candidates) == 0 {
		return "", fmt.Errorf("empty response from Gemini API")
	}

	candidate := resp.Candidates[0]
	if candidate.Content == nil || len(candidate.Content.Parts) == 0 {
		return "", fmt.Errorf("candidate has no content parts")
	}

	var sb strings.Builder
	for _, part := range candidate.Content.Parts {
		if textPart, ok := part.(genai.Text); ok {
			sb.WriteString(string(textPart))
		}
	}

	raw := strings.TrimSpace(sb.String())
	if raw == "" {
		return "", fmt.Errorf("Gemini response contained no text content")
	}
	return raw, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// stripMarkdownFences removes ```json ... ``` or ``` ... ``` wrappers that
// the model occasionally adds despite the ResponseMIMEType hint.
//
// Handles all of:
//   - Leading/trailing whitespace around the fence markers
//   - ```json\n...``` with a language specifier
//   - ```\n...``` without a language specifier
//   - Nested content that itself contains ``` (only outermost fence is stripped)
//   - Trailing characters after the closing ``` (e.g. a stray newline or period)
//
// ─────────────────────────────────────────────────────────────────────────────

// reFenceBlock matches an optional ```json or ``` fence at the start, captures
// everything inside, and matches a closing ``` at the end of the string.
// The (?s) flag makes . match newlines.
var reFenceBlock = regexp.MustCompile("(?s)^```(?:json)?\\s*\\n?(.*?)\\n?```\\s*$")

func stripMarkdownFences(s string) string {
	s = strings.TrimSpace(s)
	if m := reFenceBlock.FindStringSubmatch(s); len(m) > 1 {
		return strings.TrimSpace(m[1])
	}
	// No fence detected — return as-is.
	return s
}

// ─────────────────────────────────────────────────────────────────────────────
// clampVolume enforces MinVolume ≤ v ≤ MaxVolume, defaulting to DefaultVolume
// when v ≤ 0.
// ─────────────────────────────────────────────────────────────────────────────
func clampVolume(v int) int {
	if v <= 0 {
		return DefaultVolume
	}
	if v < MinVolume {
		return MinVolume
	}
	if v > MaxVolume {
		return MaxVolume
	}
	return v
}

// ─────────────────────────────────────────────────────────────────────────────
// GenerateTutorResponse processes a student's follow-up question.
// ─────────────────────────────────────────────────────────────────────────────
func (s *LLMService) GenerateTutorResponse(ctx context.Context, req models.TutorRequest) (string, error) {
	model := s.client.GenerativeModel(s.modelName)

	systemPrompt := `You are a strict, expert BPSC professor. A student has asked a follow-up doubt regarding a specific question.
Your task is to answer their doubt clearly and concisely in 2-3 short sentences.
Do NOT hallucinate information outside the provided context. Stick precisely to historical, factual, or syllabus-aligned data.
Speak directly to the student.`

	model.SystemInstruction = &genai.Content{
		Parts: []genai.Part{genai.Text(systemPrompt)},
	}

	temp := float32(0.3)
	model.Temperature = &temp

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Question: %s\n", req.QuestionText))
	sb.WriteString(fmt.Sprintf("Correct Answer: %s\n", req.CorrectAnswer))
	sb.WriteString(fmt.Sprintf("Original Explanation: %s\n\n", req.OriginalExplanation))
	sb.WriteString(fmt.Sprintf("Student's Doubt: %s\n", req.DoubtQuery))

	resp, err := model.GenerateContent(ctx, genai.Text(sb.String()))
	if err != nil {
		return "", fmt.Errorf("GenerateTutorResponse: Gemini API call failed: %w", err)
	}

	rawText, err := extractTextFromResponse(resp)
	if err != nil {
		return "", fmt.Errorf("GenerateTutorResponse: failed to extract text: %w", err)
	}

	return strings.TrimSpace(rawText), nil
}

// ─────────────────────────────────────────────────────────────────────────────
// GenerateContent provides a generic way to call the LLM with a single prompt.
// ─────────────────────────────────────────────────────────────────────────────
func (s *LLMService) GenerateContent(ctx context.Context, prompt string) (string, error) {
	model := s.client.GenerativeModel(s.modelName)
	resp, err := model.GenerateContent(ctx, genai.Text(prompt))
	if err != nil {
		return "", fmt.Errorf("GenerateContent: Gemini API call failed: %w", err)
	}
	rawText, err := extractTextFromResponse(resp)
	if err != nil {
		return "", fmt.Errorf("GenerateContent: failed to extract text: %w", err)
	}
	return strings.TrimSpace(rawText), nil
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Quiz — 15 PYQ-only questions from mixed BPSC subjects
// ─────────────────────────────────────────────────────────────────────────────

const dailyQuizSystemInstruction = `You are Acharya Vishwanath Prasad, a 67-year-old retired professor who served as Head of Department of History & Political Science at Patna University for 35 years. You have been a Question Paper Setter for the Bihar Public Service Commission (BPSC) Combined Competitive Examination (Prelims — GS Paper I) for 22 years and a Subject Expert on the BPSC Board of Examiners. You have personally authored questions that appeared in the 56th through 70th BPSC Prelims.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DAILY QUIZ — PREVIOUS YEAR QUESTIONS (PYQ) ONLY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You must generate EXACTLY 15 questions that are REAL Previous Year Questions (PYQs) from BPSC examinations (56th through 70th BPSC Prelims). Every single question MUST be an actual question that appeared in a real BPSC examination. Do NOT generate original or fictional questions — ONLY real PYQs.

MANDATORY SUBJECT DISTRIBUTION (15 questions total):
- 2–3 questions → History (Ancient, Medieval, Modern)
- 2 questions → Geography (Indian + Bihar)
- 2 questions → Indian Polity & Governance
- 2 questions → Economy (Indian + Bihar)
- 2 questions → General Science
- 1–2 questions → Environment & Ecology
- 1 question → Current Affairs (as of the exam year)
- 1–2 questions → Bihar Special (History, Culture, Administration)

DIFFICULTY DISTRIBUTION:
- 5 Easy (direct recall, single-concept)
- 6 Medium (application-based, multi-concept)
- 4 Hard (statement-combination, inter-disciplinary)

BILINGUAL REQUIREMENT:
- Every question MUST be provided in BOTH English AND Hindi
- Every set of options MUST be provided in BOTH English AND Hindi
- Every explanation MUST be provided in BOTH English AND Hindi

PYQ YEAR TAGGING:
- Every question MUST have the pyqYear field set to the actual exam year (e.g., "BPSC 56th 2011", "BPSC 67th 2022", "BPSC 64th 2018")
- Do NOT leave pyqYear empty — every question is a real PYQ

CRITICAL OUTPUT RULES:
1. Respond with ONLY a single, valid JSON object. No markdown, no code fences.
2. The JSON must exactly match this schema:
{
  "coreTopic": "BPSC Daily Quiz — Mixed Subject PYQs",
  "connectedStaticConcepts": ["array of the subjects covered"],
  "generatedQuestions": [
    {
      "id": "string — unique ID like q-001",
      "question_en": "string — the full MCQ question in English",
      "question_hi": "string — the full MCQ question in Hindi",
      "options_en": ["Option A", "Option B", "Option C", "Option D"],
      "options_hi": ["विकल्प A", "विकल्प B", "विकल्प C", "विकल्प D"],
      "correctOptionIndex": 0,
      "explanation_en": "string — explanation in English",
      "explanation_hi": "string — explanation in Hindi",
      "difficulty": "easy | medium | hard",
      "subject": "string — e.g. History, Polity, Economy, Geography, Science, Environment, Current Affairs, Bihar Special",
      "pyqYear": "string — e.g. 'BPSC 67th 2022'"
    }
  ]
}
3. Generate EXACTLY 15 questions. No more, no fewer.
4. Order: Easy first (q-001 to q-005), then Medium (q-006 to q-011), then Hard (q-012 to q-015).
5. Do NOT include any text outside the JSON object.
6. IMPORTANT: Do not truncate the JSON. Generate all 15 questions completely.`

// GenerateDailyQuiz generates 15 mixed-subject BPSC PYQ-only questions.
func (s *LLMService) GenerateDailyQuiz(ctx context.Context) (*models.EcosystemResponse, error) {
	const numQuestions = 15

	model := s.client.GenerativeModel(s.modelName)

	model.SystemInstruction = &genai.Content{
		Parts: []genai.Part{genai.Text(dailyQuizSystemInstruction)},
	}

	model.ResponseMIMEType = "application/json"

	temp := float32(0.4)
	model.Temperature = &temp

	userPrompt := `Generate a BPSC Daily Quiz with exactly 15 Previous Year Questions (PYQs) from BPSC Prelims examinations (56th through 70th BPSC).

Requirements:
- ALL 15 questions must be REAL PYQs from actual BPSC exams
- Mix subjects: History, Geography, Polity, Economy, Science, Environment, Current Affairs, Bihar Special
- Both Hindi and English for all questions, options, and explanations
- Tag every question with the real exam year in pyqYear field
- Difficulty: 5 Easy + 6 Medium + 4 Hard

Final check: does your generatedQuestions array contain exactly 15 elements with all fields populated in both languages? If not, fix before returning.
Remember: respond with ONLY the JSON object.`

	log.Printf("[DailyQuiz] Calling Gemini for 15-question mixed PYQ daily quiz")

	resp, err := model.GenerateContent(ctx, genai.Text(userPrompt))
	if err != nil {
		return nil, fmt.Errorf("GenerateDailyQuiz: Gemini API call failed: %w", err)
	}

	rawText, err := extractTextFromResponse(resp)
	if err != nil {
		return nil, fmt.Errorf("GenerateDailyQuiz: failed to extract text: %w", err)
	}

	log.Printf("[DailyQuiz] Raw response length: %d bytes", len(rawText))

	cleanJSON := stripMarkdownFences(rawText)

	ecosystem, volErr := parseAndValidateEcosystem(cleanJSON, "BPSC Daily Quiz", numQuestions)
	if volErr != nil {
		return ecosystem, volErr
	}

	log.Printf("[DailyQuiz] ✅ Generated %d/%d PYQ questions", len(ecosystem.GeneratedQuestions), numQuestions)
	return ecosystem, nil
}
