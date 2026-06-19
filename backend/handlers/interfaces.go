package handlers

import (
	"context"
)

// LLMService defines the required interface for AI generation,
// allowing handlers to operate without concrete dependencies on the services package.
type LLMService interface {
	GenerateContent(ctx context.Context, prompt string) (string, error)
}
