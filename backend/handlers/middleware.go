package handlers

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"bpsc-engine/models"
	"bpsc-engine/services"
)

// ─────────────────────────────────────────────────────────────────────────────
// Context keys for JWT user claims
// ─────────────────────────────────────────────────────────────────────────────

type contextKey string

const userContextKey contextKey = "user_claims"

// ContextWithUser injects token claims into the request context.
func ContextWithUser(ctx context.Context, claims *models.TokenClaims) context.Context {
	return context.WithValue(ctx, userContextKey, claims)
}

// GetUserFromContext extracts token claims from the request context.
// Returns nil if no claims are present (unauthenticated request).
func GetUserFromContext(ctx context.Context) *models.TokenClaims {
	claims, ok := ctx.Value(userContextKey).(*models.TokenClaims)
	if !ok {
		return nil
	}
	return claims
}

// ─────────────────────────────────────────────────────────────────────────────
// JWT Authentication Middleware
// ─────────────────────────────────────────────────────────────────────────────

// JWTAuthMiddleware validates the Authorization: Bearer <token> header
// and injects user claims into the request context.
func JWTAuthMiddleware(authService *services.AuthService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				jsonError(w, "missing authorization header", http.StatusUnauthorized)
				return
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
				jsonError(w, "invalid authorization header format", http.StatusUnauthorized)
				return
			}

			claims, err := authService.ValidateAccessToken(parts[1])
			if err != nil {
				jsonError(w, "invalid or expired token", http.StatusUnauthorized)
				return
			}

			// Inject claims into context
			ctx := ContextWithUser(r.Context(), claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// RBAC Middleware
// ─────────────────────────────────────────────────────────────────────────────

// RequireRole creates middleware that restricts access to specific roles.
// Must be used AFTER JWTAuthMiddleware.
func RequireRole(allowedRoles ...string) func(http.Handler) http.Handler {
	roleSet := make(map[string]bool, len(allowedRoles))
	for _, role := range allowedRoles {
		roleSet[role] = true
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims := GetUserFromContext(r.Context())
			if claims == nil {
				jsonError(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			if !roleSet[claims.Role] {
				jsonError(w, "insufficient permissions", http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// OptionalAuth Middleware — injects claims if token present, but doesn't block
// ─────────────────────────────────────────────────────────────────────────────

// OptionalAuthMiddleware is like JWTAuthMiddleware but does NOT reject requests
// without a token. Use for endpoints that work for both anonymous and authenticated users.
func OptionalAuthMiddleware(authService *services.AuthService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader != "" {
				parts := strings.SplitN(authHeader, " ", 2)
				if len(parts) == 2 && strings.EqualFold(parts[0], "bearer") {
					claims, err := authService.ValidateAccessToken(parts[1])
					if err == nil {
						ctx := ContextWithUser(r.Context(), claims)
						r = r.WithContext(ctx)
					}
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}

// CORSMiddleware wraps an http.Handler to inject permissive CORS headers
// for local Flutter development (both web and device emulators).
//
// Allowed origins: any localhost port.
// Allowed methods: GET, POST, PUT, DELETE, OPTIONS.
// Allowed headers: Content-Type, Authorization, X-Request-ID, X-User-ID.
func CORSMiddleware(next http.Handler) http.Handler {
	// Production: set CORS_ALLOWED_ORIGINS=https://app.example.com,https://staging.example.com
	allowedOrigins := strings.Split(strings.TrimSpace(corsAllowedOriginsEnv()), ",")

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		if origin != "" && isAllowedOrigin(origin, allowedOrigins) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
		}

		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Request-ID, X-User-ID")
		w.Header().Set("Access-Control-Allow-Credentials", "true")
		w.Header().Set("Access-Control-Max-Age", "86400")

		// Handle preflight requests
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// corsAllowedOriginsEnv reads the CORS_ALLOWED_ORIGINS env var.
// Defined as a function so middleware.go doesn't need to import "os" at package init.
func corsAllowedOriginsEnv() string {
	return os.Getenv("CORS_ALLOWED_ORIGINS")
}

// isAllowedOrigin checks if the origin is in the allowed list or is a localhost variant.
func isAllowedOrigin(origin string, allowed []string) bool {
	for _, a := range allowed {
		if strings.TrimSpace(a) != "" && strings.EqualFold(origin, strings.TrimSpace(a)) {
			return true
		}
	}
	return isLocalOrigin(origin)
}

// LoggingMiddleware logs each incoming request with method, path, and duration.
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Wrap ResponseWriter to capture status code
		wrapped := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(wrapped, r)

		log.Printf(
			"[%s] %s %s — %d (%s)",
			r.Method,
			r.URL.Path,
			r.RemoteAddr,
			wrapped.statusCode,
			time.Since(start).Round(time.Microsecond),
		)
	})
}

// statusRecorder wraps http.ResponseWriter to capture the status code.
type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (sr *statusRecorder) WriteHeader(code int) {
	sr.statusCode = code
	sr.ResponseWriter.WriteHeader(code)
}

// isLocalOrigin checks if the origin is a localhost variant.
func isLocalOrigin(origin string) bool {
	lower := strings.ToLower(origin)
	return strings.HasPrefix(lower, "http://localhost") ||
		strings.HasPrefix(lower, "https://localhost") ||
		strings.HasPrefix(lower, "http://127.0.0.1") ||
		strings.HasPrefix(lower, "https://127.0.0.1") ||
		strings.HasPrefix(lower, "http://[::1]") ||
		strings.HasPrefix(lower, "https://[::1]")
}
