package auth

import (
	"time"

	"github.com/google/uuid"
)

// User represents a registered user account in PostgreSQL.
type User struct {
	ID           uuid.UUID `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

// RefreshToken represents a stored refresh token with its rotation and family tracking.
type RefreshToken struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	FamilyID  uuid.UUID  `json:"family_id"`
	TokenHash string     `json:"-"`
	ExpiresAt time.Time  `json:"expires_at"`
	RotatedAt *time.Time `json:"rotated_at,omitempty"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}

// UserResponse is the user representation sent in auth responses.
type UserResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

// RegisterRequest holds registration inputs.
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
}

// LoginRequest holds login credentials.
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// RefreshRequest holds the refresh token for rotation.
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// LogoutRequest holds the refresh token for revocation.
type LogoutRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// AuthResponse represents the standard token pair response.
type AuthResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	ExpiresIn    int          `json:"expires_in"` // in seconds, e.g. 900
	User         UserResponse `json:"user"`
}
