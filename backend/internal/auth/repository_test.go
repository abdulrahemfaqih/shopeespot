package auth

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/abdulrahemfaqih/shopeespot/internal/config"
	"github.com/abdulrahemfaqih/shopeespot/internal/db"
)

func TestAuthRepository_Integration(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test in short mode")
	}

	cfg, err := config.Load()
	if err != nil || cfg.DatabaseURL == "" {
		t.Skip("skipping integration test: DATABASE_URL not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		t.Skipf("cannot connect to database: %v", err)
	}
	defer pool.Close()

	repo := NewRepository(pool)
	now := time.Now().UTC()
	userID := uuid.New()
	email := "authtest_" + userID.String()[:8] + "@example.com"

	// 1. Create user
	user := &User{
		ID:           userID,
		Email:        email,
		PasswordHash: "hashed-pw",
		CreatedAt:    now,
	}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("failed to create user: %v", err)
	}
	defer func() {
		_, _ = pool.Exec(context.Background(), "DELETE FROM users WHERE id = $1", userID)
	}()

	// 2. Duplicate email should return ErrEmailAlreadyExists
	if err := repo.CreateUser(ctx, user); err != ErrEmailAlreadyExists {
		t.Fatalf("expected ErrEmailAlreadyExists, got: %v", err)
	}

	// 3. Create initial refresh token
	rawToken, tokenHash, _ := GenerateRefreshToken()
	familyID := uuid.New()
	initialToken := &RefreshToken{
		ID:        uuid.New(),
		UserID:    userID,
		FamilyID:  familyID,
		TokenHash: tokenHash,
		ExpiresAt: now.Add(30 * 24 * time.Hour),
		CreatedAt: now,
	}
	if err := repo.CreateRefreshToken(ctx, initialToken); err != nil {
		t.Fatalf("failed to create refresh token: %v", err)
	}

	// 4. Normal rotation
	_, newHash, _ := GenerateRefreshToken()
	newToken := &RefreshToken{
		ID:        uuid.New(),
		TokenHash: newHash,
		ExpiresAt: now.Add(30 * 24 * time.Hour),
		CreatedAt: now,
	}
	rotatedToken, dbUser, err := repo.RotateRefreshToken(ctx, tokenHash, newToken, 60*time.Second, now)
	if err != nil {
		t.Fatalf("rotation failed: %v", err)
	}
	if rotatedToken.FamilyID != familyID || dbUser.Email != email {
		t.Fatalf("mismatch in rotated token family or user email")
	}

	_ = rawToken
}
