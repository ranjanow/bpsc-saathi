package services

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"time"

	"bpsc-engine/models"
	"bpsc-engine/repositories"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// ─────────────────────────────────────────────────────────────────────────────
// AuthService — JWT token management, password hashing, and auth flows
// ─────────────────────────────────────────────────────────────────────────────

const (
	// AccessTokenDuration is the lifetime of a JWT access token.
	AccessTokenDuration = 15 * time.Minute

	// RefreshTokenDuration is the lifetime of a refresh token.
	RefreshTokenDuration = 7 * 24 * time.Hour

	// PasswordResetTokenDuration is the lifetime of a password reset token.
	PasswordResetTokenDuration = 1 * time.Hour

	// BcryptCost is the bcrypt hashing cost factor.
	BcryptCost = 12
)

// AuthService handles authentication, token generation, and password management.
type AuthService struct {
	jwtSecret []byte
	userRepo  *repositories.UserRepository
}

// NewAuthService creates a new AuthService.
func NewAuthService(jwtSecret string, userRepo *repositories.UserRepository) *AuthService {
	return &AuthService{
		jwtSecret: []byte(jwtSecret),
		userRepo:  userRepo,
	}
}

// ═══════════════════════════════════════════════════════════════════════════
// Password Hashing
// ═══════════════════════════════════════════════════════════════════════════

// HashPassword hashes a plaintext password using bcrypt.
func (s *AuthService) HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), BcryptCost)
	if err != nil {
		return "", fmt.Errorf("HashPassword: %w", err)
	}
	return string(bytes), nil
}

// VerifyPassword compares a plaintext password against a bcrypt hash.
func (s *AuthService) VerifyPassword(hash, password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// ═══════════════════════════════════════════════════════════════════════════
// JWT Access Tokens
// ═══════════════════════════════════════════════════════════════════════════

// jwtCustomClaims extends jwt.RegisteredClaims with user-specific fields.
type jwtCustomClaims struct {
	UserID string `json:"userId"`
	Email  string `json:"email"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

// GenerateAccessToken creates a signed JWT access token for the given user.
func (s *AuthService) GenerateAccessToken(user *models.User) (string, error) {
	now := time.Now()
	claims := jwtCustomClaims{
		UserID: user.ID,
		Email:  user.Email,
		Role:   user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(AccessTokenDuration)),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			Issuer:    "bpsc-saathi",
			Subject:   user.ID,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(s.jwtSecret)
	if err != nil {
		return "", fmt.Errorf("GenerateAccessToken: %w", err)
	}
	return signed, nil
}

// ValidateAccessToken parses and validates a JWT access token, returning claims.
func (s *AuthService) ValidateAccessToken(tokenString string) (*models.TokenClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &jwtCustomClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return s.jwtSecret, nil
	})

	if err != nil {
		return nil, fmt.Errorf("ValidateAccessToken: %w", err)
	}

	claims, ok := token.Claims.(*jwtCustomClaims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("ValidateAccessToken: invalid token claims")
	}

	return &models.TokenClaims{
		UserID: claims.UserID,
		Email:  claims.Email,
		Role:   claims.Role,
	}, nil
}

// ═══════════════════════════════════════════════════════════════════════════
// Refresh Tokens
// ═══════════════════════════════════════════════════════════════════════════

// GenerateRefreshToken creates an opaque refresh token, stores its hash in DB.
// Returns the raw token string (to send to client).
func (s *AuthService) GenerateRefreshToken(userID string) (string, error) {
	// Generate 32 bytes of cryptographic randomness
	rawBytes := make([]byte, 32)
	if _, err := rand.Read(rawBytes); err != nil {
		return "", fmt.Errorf("GenerateRefreshToken: %w", err)
	}
	rawToken := hex.EncodeToString(rawBytes) // 64-char hex string

	// Hash it for DB storage (we never store raw tokens)
	tokenHash := hashToken(rawToken)
	expiresAt := time.Now().Add(RefreshTokenDuration)

	if err := s.userRepo.StoreRefreshToken(userID, tokenHash, expiresAt); err != nil {
		return "", err
	}

	return rawToken, nil
}

// RefreshTokens validates a refresh token and issues a new access + refresh token pair.
// This implements token rotation: the old refresh token is revoked.
func (s *AuthService) RefreshTokens(rawRefreshToken string) (*models.AuthResponse, error) {
	tokenHash := hashToken(rawRefreshToken)

	// Look up the refresh token
	record, err := s.userRepo.GetRefreshToken(tokenHash)
	if err != nil {
		return nil, err
	}
	if record == nil {
		return nil, fmt.Errorf("RefreshTokens: invalid refresh token")
	}

	// Check if revoked or expired
	if record.Revoked {
		// Potential token theft — revoke ALL tokens for this user
		log.Printf("[Auth] ⚠️  Revoked refresh token reuse detected for user=%s — revoking all", record.UserID)
		_ = s.userRepo.RevokeAllUserRefreshTokens(record.UserID)
		return nil, fmt.Errorf("RefreshTokens: token has been revoked (possible theft)")
	}
	if time.Now().After(record.ExpiresAt) {
		return nil, fmt.Errorf("RefreshTokens: token has expired")
	}

	// Rotate: revoke old, issue new
	if err := s.userRepo.RevokeRefreshToken(tokenHash); err != nil {
		return nil, err
	}

	// Get user
	user, err := s.userRepo.GetUserByID(record.UserID)
	if err != nil || user == nil {
		return nil, fmt.Errorf("RefreshTokens: user not found")
	}

	// Generate new token pair
	accessToken, err := s.GenerateAccessToken(user)
	if err != nil {
		return nil, err
	}

	newRefreshToken, err := s.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, err
	}

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
		ExpiresIn:    int(AccessTokenDuration.Seconds()),
		User:         user.ToPublic(),
	}, nil
}

// RevokeRefreshToken revokes a specific refresh token (for logout).
func (s *AuthService) RevokeRefreshToken(rawRefreshToken string) error {
	tokenHash := hashToken(rawRefreshToken)
	return s.userRepo.RevokeRefreshToken(tokenHash)
}

// ═══════════════════════════════════════════════════════════════════════════
// Password Reset
// ═══════════════════════════════════════════════════════════════════════════

// GeneratePasswordResetToken creates a reset token for the given user.
// Returns the raw token string (to send via email / log).
func (s *AuthService) GeneratePasswordResetToken(userID string) (string, error) {
	rawBytes := make([]byte, 32)
	if _, err := rand.Read(rawBytes); err != nil {
		return "", fmt.Errorf("GeneratePasswordResetToken: %w", err)
	}
	rawToken := hex.EncodeToString(rawBytes)

	tokenHash := hashToken(rawToken)
	expiresAt := time.Now().Add(PasswordResetTokenDuration)

	if err := s.userRepo.StorePasswordResetToken(userID, tokenHash, expiresAt); err != nil {
		return "", err
	}

	return rawToken, nil
}

// ValidatePasswordResetToken validates a reset token and returns the user ID.
func (s *AuthService) ValidatePasswordResetToken(rawToken string) (string, error) {
	tokenHash := hashToken(rawToken)

	record, err := s.userRepo.GetPasswordResetToken(tokenHash)
	if err != nil {
		return "", err
	}
	if record == nil {
		return "", fmt.Errorf("ValidatePasswordResetToken: invalid token")
	}
	if record.Used {
		return "", fmt.Errorf("ValidatePasswordResetToken: token already used")
	}
	if time.Now().After(record.ExpiresAt) {
		return "", fmt.Errorf("ValidatePasswordResetToken: token expired")
	}

	return record.UserID, nil
}

// ResetPassword validates the reset token, updates the password, and marks the token used.
func (s *AuthService) ResetPassword(rawToken, newPassword string) error {
	userID, err := s.ValidatePasswordResetToken(rawToken)
	if err != nil {
		return err
	}

	hash, err := s.HashPassword(newPassword)
	if err != nil {
		return err
	}

	if err := s.userRepo.UpdatePasswordHash(userID, hash); err != nil {
		return err
	}

	tokenHash := hashToken(rawToken)
	if err := s.userRepo.MarkPasswordResetTokenUsed(tokenHash); err != nil {
		return err
	}

	// Revoke all refresh tokens (force re-login after password change)
	_ = s.userRepo.RevokeAllUserRefreshTokens(userID)

	log.Printf("[Auth] ✅ Password reset for user=%s", userID)
	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// Auth Flows
// ═══════════════════════════════════════════════════════════════════════════

// Signup creates a new user with email+password.
func (s *AuthService) Signup(req *models.SignupRequest) (*models.AuthResponse, error) {
	// Check if email already exists
	existing, err := s.userRepo.GetUserByEmail(req.Email)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, fmt.Errorf("Signup: email already registered")
	}

	// Hash password
	hash, err := s.HashPassword(req.Password)
	if err != nil {
		return nil, err
	}

	// Create user
	user := &models.User{
		Email:        req.Email,
		PasswordHash: hash,
		FullName:     req.FullName,
		Provider:     "email",
		Role:         models.RoleStudent,
		IsVerified:   false,
	}

	created, err := s.userRepo.CreateUser(user)
	if err != nil {
		return nil, err
	}

	// Generate tokens
	accessToken, err := s.GenerateAccessToken(created)
	if err != nil {
		return nil, err
	}

	refreshToken, err := s.GenerateRefreshToken(created.ID)
	if err != nil {
		return nil, err
	}

	_ = s.userRepo.UpdateLastLogin(created.ID)

	log.Printf("[Auth] ✅ Signup complete — user=%s email=%s", created.ID, created.Email)

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int(AccessTokenDuration.Seconds()),
		User:         created.ToPublic(),
	}, nil
}

// Login authenticates with email+password.
func (s *AuthService) Login(req *models.LoginRequest) (*models.AuthResponse, error) {
	user, err := s.userRepo.GetUserByEmail(req.Email)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, fmt.Errorf("Login: invalid email or password")
	}

	if user.PasswordHash == "" {
		return nil, fmt.Errorf("Login: this account uses %s sign-in", user.Provider)
	}

	if !s.VerifyPassword(user.PasswordHash, req.Password) {
		return nil, fmt.Errorf("Login: invalid email or password")
	}

	accessToken, err := s.GenerateAccessToken(user)
	if err != nil {
		return nil, err
	}

	refreshToken, err := s.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, err
	}

	_ = s.userRepo.UpdateLastLogin(user.ID)

	log.Printf("[Auth] ✅ Login successful — user=%s email=%s", user.ID, user.Email)

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int(AccessTokenDuration.Seconds()),
		User:         user.ToPublic(),
	}, nil
}

// GoogleAuth handles Google OAuth sign-in.
// In a production system, the idToken would be verified against Google's servers.
// For now, we extract email and name from the request and create/login the user.
func (s *AuthService) GoogleAuth(email, fullName, avatarURL string) (*models.AuthResponse, error) {
	user, err := s.userRepo.GetUserByEmail(email)
	if err != nil {
		return nil, err
	}

	if user == nil {
		// Create new Google user
		user = &models.User{
			Email:      email,
			FullName:   fullName,
			AvatarURL:  avatarURL,
			Provider:   "google",
			Role:       models.RoleStudent,
			IsVerified: true, // Google accounts are pre-verified
		}
		user, err = s.userRepo.CreateUser(user)
		if err != nil {
			return nil, err
		}
		log.Printf("[Auth] ✅ Google signup — user=%s email=%s", user.ID, user.Email)
	} else {
		log.Printf("[Auth] ✅ Google login — user=%s email=%s", user.ID, user.Email)
	}

	accessToken, err := s.GenerateAccessToken(user)
	if err != nil {
		return nil, err
	}

	refreshToken, err := s.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, err
	}

	_ = s.userRepo.UpdateLastLogin(user.ID)

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int(AccessTokenDuration.Seconds()),
		User:         user.ToPublic(),
	}, nil
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

// hashToken returns the SHA-256 hex digest of a raw token.
// We never store raw tokens in the database.
func hashToken(rawToken string) string {
	h := sha256.Sum256([]byte(rawToken))
	return hex.EncodeToString(h[:])
}
