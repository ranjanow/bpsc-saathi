package models

import "time"

// ─────────────────────────────────────────────────────────────────────────────
// User — core user entity backed by the `users` table
// ─────────────────────────────────────────────────────────────────────────────

// User represents a registered user in the system.
type User struct {
	ID                string    `json:"id"`
	Email             string    `json:"email"`
	PasswordHash      string    `json:"-"` // Never serialized to JSON
	FullName          string    `json:"fullName"`
	AvatarURL         string    `json:"avatarUrl"`
	Provider          string    `json:"provider"`          // "email", "google"
	Role              string    `json:"role"`              // "student", "mentor", "admin"
	IsVerified        bool      `json:"isVerified"`
	TotalXP           int       `json:"totalXp"`
	StreakDays        int       `json:"streakDays"`
	QuizzesTaken     int       `json:"quizzesTaken"`
	Accuracy          float64   `json:"accuracy"`
	PreferredLanguage string    `json:"preferredLanguage"` // "en", "hi", "both"
	ThemeMode         string    `json:"themeMode"`         // "vibrant", "professional", "darkTech"
	Bio               string    `json:"bio"`
	TargetExam        string    `json:"targetExam"`
	CreatedAt         time.Time `json:"createdAt"`
	UpdatedAt         time.Time `json:"updatedAt"`
	LastLogin         *time.Time `json:"lastLogin,omitempty"`
}

// UserPublic returns a safe-to-serialize subset of User (no password hash).
// Since PasswordHash is tagged `json:"-"` this is primarily for documentation.
type UserPublic struct {
	ID                string     `json:"id"`
	Email             string     `json:"email"`
	FullName          string     `json:"fullName"`
	AvatarURL         string     `json:"avatarUrl"`
	Provider          string     `json:"provider"`
	Role              string     `json:"role"`
	IsVerified        bool       `json:"isVerified"`
	TotalXP           int        `json:"totalXp"`
	StreakDays        int        `json:"streakDays"`
	QuizzesTaken     int        `json:"quizzesTaken"`
	Accuracy          float64    `json:"accuracy"`
	PreferredLanguage string     `json:"preferredLanguage"`
	ThemeMode         string     `json:"themeMode"`
	Bio               string     `json:"bio"`
	TargetExam        string     `json:"targetExam"`
	CreatedAt         time.Time  `json:"createdAt"`
	LastLogin         *time.Time `json:"lastLogin,omitempty"`
}

// ToPublic converts a User to its public representation.
func (u *User) ToPublic() UserPublic {
	return UserPublic{
		ID:                u.ID,
		Email:             u.Email,
		FullName:          u.FullName,
		AvatarURL:         u.AvatarURL,
		Provider:          u.Provider,
		Role:              u.Role,
		IsVerified:        u.IsVerified,
		TotalXP:           u.TotalXP,
		StreakDays:        u.StreakDays,
		QuizzesTaken:     u.QuizzesTaken,
		Accuracy:          u.Accuracy,
		PreferredLanguage: u.PreferredLanguage,
		ThemeMode:         u.ThemeMode,
		Bio:               u.Bio,
		TargetExam:        u.TargetExam,
		CreatedAt:         u.CreatedAt,
		LastLogin:         u.LastLogin,
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Request / Response types
// ─────────────────────────────────────────────────────────────────────────────

// SignupRequest is the JSON body for POST /api/v1/auth/signup.
type SignupRequest struct {
	FullName string `json:"fullName"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginRequest is the JSON body for POST /api/v1/auth/login.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// GoogleAuthRequest is the JSON body for POST /api/v1/auth/google.
type GoogleAuthRequest struct {
	IDToken string `json:"idToken"` // Google ID token from client SDK
}

// RefreshRequest is the JSON body for POST /api/v1/auth/refresh.
type RefreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

// ForgotPasswordRequest is the JSON body for POST /api/v1/auth/forgot-password.
type ForgotPasswordRequest struct {
	Email string `json:"email"`
}

// ResetPasswordRequest is the JSON body for POST /api/v1/auth/reset-password.
type ResetPasswordRequest struct {
	Token       string `json:"token"`
	NewPassword string `json:"newPassword"`
}

// LogoutRequest is the JSON body for POST /api/v1/auth/logout.
type LogoutRequest struct {
	RefreshToken string `json:"refreshToken"`
}

// AuthResponse is returned on successful signup/login/refresh.
type AuthResponse struct {
	AccessToken  string     `json:"accessToken"`
	RefreshToken string     `json:"refreshToken"`
	ExpiresIn    int        `json:"expiresIn"` // seconds until access token expires
	User         UserPublic `json:"user"`
}

// UpdateProfileRequest is the JSON body for PUT /api/v1/profile.
type UpdateProfileRequest struct {
	FullName          *string `json:"fullName,omitempty"`
	Bio               *string `json:"bio,omitempty"`
	TargetExam        *string `json:"targetExam,omitempty"`
	PreferredLanguage *string `json:"preferredLanguage,omitempty"`
	ThemeMode         *string `json:"themeMode,omitempty"`
	AvatarURL         *string `json:"avatarUrl,omitempty"`
}

// ─────────────────────────────────────────────────────────────────────────────
// JWT Token Claims
// ─────────────────────────────────────────────────────────────────────────────

// TokenClaims holds the custom JWT payload fields.
type TokenClaims struct {
	UserID string `json:"userId"`
	Email  string `json:"email"`
	Role   string `json:"role"`
}

// ─────────────────────────────────────────────────────────────────────────────
// Roles
// ─────────────────────────────────────────────────────────────────────────────

const (
	RoleStudent = "student"
	RoleMentor  = "mentor"
	RoleAdmin   = "admin"
)

// ValidRoles is the set of valid user roles.
var ValidRoles = map[string]bool{
	RoleStudent: true,
	RoleMentor:  true,
	RoleAdmin:   true,
}
