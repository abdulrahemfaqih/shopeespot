package auth

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/abdulrahemfaqih/shopeespot/internal/httpx"
)

type mockRepository struct {
	mu     sync.Mutex
	users  map[uuid.UUID]*User
	tokens map[string]*RefreshToken
}

func newMockRepository() *mockRepository {
	return &mockRepository{
		users:  make(map[uuid.UUID]*User),
		tokens: make(map[string]*RefreshToken),
	}
}

func (m *mockRepository) CreateUser(ctx context.Context, u *User) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, existing := range m.users {
		if strings.EqualFold(existing.Email, u.Email) {
			return ErrEmailAlreadyExists
		}
	}
	m.users[u.ID] = u
	return nil
}

func (m *mockRepository) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, u := range m.users {
		if strings.EqualFold(u.Email, email) {
			return u, nil
		}
	}
	return nil, ErrUserNotFound
}

func (m *mockRepository) GetUserByID(ctx context.Context, id uuid.UUID) (*User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	u, exists := m.users[id]
	if !exists {
		return nil, ErrUserNotFound
	}
	return u, nil
}

func (m *mockRepository) CreateRefreshToken(ctx context.Context, t *RefreshToken) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.tokens[t.TokenHash] = t
	return nil
}

func (m *mockRepository) RotateRefreshToken(
	ctx context.Context,
	oldHash string,
	newToken *RefreshToken,
	grace time.Duration,
	now time.Time,
) (*RefreshToken, *User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	oldToken, exists := m.tokens[oldHash]
	if !exists {
		return nil, nil, ErrInvalidRefresh
	}

	if oldToken.RevokedAt != nil || !now.Before(oldToken.ExpiresAt) {
		return nil, nil, ErrInvalidRefresh
	}

	if oldToken.RotatedAt != nil {
		elapsed := now.Sub(*oldToken.RotatedAt)
		if elapsed > grace {
			for _, t := range m.tokens {
				if t.FamilyID == oldToken.FamilyID && t.RevokedAt == nil {
					t.RevokedAt = &now
				}
			}
			return nil, nil, ErrReuseDetected
		}
	} else {
		oldToken.RotatedAt = &now
	}

	newToken.UserID = oldToken.UserID
	newToken.FamilyID = oldToken.FamilyID
	m.tokens[newToken.TokenHash] = newToken

	user := m.users[oldToken.UserID]
	return newToken, user, nil
}

func (m *mockRepository) RevokeFamilyByTokenHash(ctx context.Context, tokenHash string, revokedAt time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	target, exists := m.tokens[tokenHash]
	if !exists {
		return nil
	}

	for _, t := range m.tokens {
		if t.FamilyID == target.FamilyID && t.RevokedAt == nil {
			t.RevokedAt = &revokedAt
		}
	}
	return nil
}

func setupTestService(repo *mockRepository, now time.Time) (Service, ServiceConfig) {
	cfg := ServiceConfig{
		JWTSecret:           []byte("secret-key-must-be-at-least-32-bytes!"),
		AccessTokenTTL:      15 * time.Minute,
		RefreshTokenTTL:     30 * 24 * time.Hour,
		RefreshGrace:        60 * time.Second,
		BcryptCost:          4, // fast for tests
		RegistrationEnabled: true,
		NowFunc:             func() time.Time { return now },
	}
	svc := NewService(repo, cfg)
	return svc, cfg
}

func TestRotation_Normal(t *testing.T) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc, _ := setupTestService(repo, baseTime)

	ctx := context.Background()
	regResp, err := svc.Register(ctx, RegisterRequest{
		Email:    "driver@example.com",
		Password: "password123",
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	refreshResp, err := svc.Refresh(ctx, RefreshRequest{
		RefreshToken: regResp.RefreshToken,
	})
	if err != nil {
		t.Fatalf("normal refresh failed: %v", err)
	}

	if refreshResp.AccessToken == "" || refreshResp.RefreshToken == "" {
		t.Fatal("expected non-empty tokens in refresh response")
	}
	if refreshResp.RefreshToken == regResp.RefreshToken {
		t.Fatal("expected new refresh token to be different from original")
	}
}

func TestRotation_WithinGrace(t *testing.T) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	currentTime := baseTime
	cfg := ServiceConfig{
		JWTSecret:           []byte("secret-key-must-be-at-least-32-bytes!"),
		AccessTokenTTL:      15 * time.Minute,
		RefreshTokenTTL:     30 * 24 * time.Hour,
		RefreshGrace:        60 * time.Second,
		BcryptCost:          4,
		RegistrationEnabled: true,
		NowFunc:             func() time.Time { return currentTime },
	}
	svc := NewService(repo, cfg)

	ctx := context.Background()
	regResp, _ := svc.Register(ctx, RegisterRequest{Email: "driver@example.com", Password: "password123"})
	originalToken := regResp.RefreshToken

	// First rotation at t=0
	_, err := svc.Refresh(ctx, RefreshRequest{RefreshToken: originalToken})
	if err != nil {
		t.Fatalf("first refresh failed: %v", err)
	}

	// Second rotation of same token at t=30s (within 60s grace)
	currentTime = baseTime.Add(30 * time.Second)
	graceResp, err := svc.Refresh(ctx, RefreshRequest{RefreshToken: originalToken})
	if err != nil {
		t.Fatalf("within-grace refresh should succeed, got: %v", err)
	}

	if graceResp.AccessToken == "" || graceResp.RefreshToken == "" {
		t.Fatal("expected valid token pair on within-grace refresh")
	}
}

func TestRotation_OutsideGrace_ReuseDetected(t *testing.T) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	currentTime := baseTime
	cfg := ServiceConfig{
		JWTSecret:           []byte("secret-key-must-be-at-least-32-bytes!"),
		AccessTokenTTL:      15 * time.Minute,
		RefreshTokenTTL:     30 * 24 * time.Hour,
		RefreshGrace:        60 * time.Second,
		BcryptCost:          4,
		RegistrationEnabled: true,
		NowFunc:             func() time.Time { return currentTime },
	}
	svc := NewService(repo, cfg)

	ctx := context.Background()
	regResp, _ := svc.Register(ctx, RegisterRequest{Email: "driver@example.com", Password: "password123"})
	originalToken := regResp.RefreshToken

	// First rotation at t=0
	firstRefreshResp, err := svc.Refresh(ctx, RefreshRequest{RefreshToken: originalToken})
	if err != nil {
		t.Fatalf("first refresh failed: %v", err)
	}

	// Reuse of old token at t=65s (outside 60s grace)
	currentTime = baseTime.Add(65 * time.Second)
	_, err = svc.Refresh(ctx, RefreshRequest{RefreshToken: originalToken})
	if err == nil {
		t.Fatal("expected reuse_detected error, got nil")
	}

	var appErr *httpx.AppError
	if !errors.As(err, &appErr) || appErr.Code != "reuse_detected" {
		t.Fatalf("expected reuse_detected code, got: %v", err)
	}

	// Verify the whole family was revoked: subsequent refresh with the newest token also fails
	_, err = svc.Refresh(ctx, RefreshRequest{RefreshToken: firstRefreshResp.RefreshToken})
	if err == nil {
		t.Fatal("expected entire family to be revoked after reuse")
	}
}

func TestRotation_Expired(t *testing.T) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	currentTime := baseTime
	cfg := ServiceConfig{
		JWTSecret:           []byte("secret-key-must-be-at-least-32-bytes!"),
		AccessTokenTTL:      15 * time.Minute,
		RefreshTokenTTL:     1 * time.Hour, // 1 hour TTL
		RefreshGrace:        60 * time.Second,
		BcryptCost:          4,
		RegistrationEnabled: true,
		NowFunc:             func() time.Time { return currentTime },
	}
	svc := NewService(repo, cfg)

	ctx := context.Background()
	regResp, _ := svc.Register(ctx, RegisterRequest{Email: "driver@example.com", Password: "password123"})

	// Fast forward 2 hours (token expired)
	currentTime = baseTime.Add(2 * time.Hour)
	_, err := svc.Refresh(ctx, RefreshRequest{RefreshToken: regResp.RefreshToken})
	if err == nil {
		t.Fatal("expected invalid_refresh error on expired token, got nil")
	}

	var appErr *httpx.AppError
	if !errors.As(err, &appErr) || appErr.Code != "invalid_refresh" {
		t.Fatalf("expected invalid_refresh code, got: %v", err)
	}
}

func TestRotation_Revoked(t *testing.T) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc, _ := setupTestService(repo, baseTime)

	ctx := context.Background()
	regResp, _ := svc.Register(ctx, RegisterRequest{Email: "driver@example.com", Password: "password123"})

	// Logout revokes the family
	err := svc.Logout(ctx, LogoutRequest{RefreshToken: regResp.RefreshToken})
	if err != nil {
		t.Fatalf("logout failed: %v", err)
	}

	// Refresh after logout
	_, err = svc.Refresh(ctx, RefreshRequest{RefreshToken: regResp.RefreshToken})
	if err == nil {
		t.Fatal("expected invalid_refresh error on revoked token, got nil")
	}

	var appErr *httpx.AppError
	if !errors.As(err, &appErr) || appErr.Code != "invalid_refresh" {
		t.Fatalf("expected invalid_refresh code, got: %v", err)
	}
}

func TestLogin_FailureAlwaysInvalidCredentials(t *testing.T) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc, _ := setupTestService(repo, baseTime)

	ctx := context.Background()
	_, _ = svc.Register(ctx, RegisterRequest{Email: "driver@example.com", Password: "password123"})

	// Scenario 1: Non-existent email
	_, err := svc.Login(ctx, LoginRequest{Email: "unknown@example.com", Password: "password123"})
	if err == nil {
		t.Fatal("expected login failure for unknown user")
	}
	var appErr *httpx.AppError
	if !errors.As(err, &appErr) || appErr.Code != "invalid_credentials" {
		t.Fatalf("expected invalid_credentials code, got: %v", err)
	}

	// Scenario 2: Incorrect password
	_, err = svc.Login(ctx, LoginRequest{Email: "driver@example.com", Password: "wrong-password"})
	if err == nil {
		t.Fatal("expected login failure for wrong password")
	}
	if !errors.As(err, &appErr) || appErr.Code != "invalid_credentials" {
		t.Fatalf("expected invalid_credentials code, got: %v", err)
	}
}

func TestRegistration_Disabled(t *testing.T) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	cfg := ServiceConfig{
		JWTSecret:           []byte("secret-key-must-be-at-least-32-bytes!"),
		AccessTokenTTL:      15 * time.Minute,
		RefreshTokenTTL:     30 * 24 * time.Hour,
		RefreshGrace:        60 * time.Second,
		BcryptCost:          4,
		RegistrationEnabled: false, // disabled
		NowFunc:             func() time.Time { return baseTime },
	}
	svc := NewService(repo, cfg)

	ctx := context.Background()
	_, err := svc.Register(ctx, RegisterRequest{Email: "driver@example.com", Password: "password123"})
	if err == nil {
		t.Fatal("expected error when registration is disabled")
	}

	var appErr *httpx.AppError
	if !errors.As(err, &appErr) || appErr.Code != "registration_disabled" {
		t.Fatalf("expected registration_disabled code, got: %v", err)
	}
}

func TestRegistration_EmailTaken(t *testing.T) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc, _ := setupTestService(repo, baseTime)

	ctx := context.Background()
	_, err := svc.Register(ctx, RegisterRequest{Email: "driver@example.com", Password: "password123"})
	if err != nil {
		t.Fatalf("first registration failed: %v", err)
	}

	_, err = svc.Register(ctx, RegisterRequest{Email: "DRIVER@example.com", Password: "password123"})
	if err == nil {
		t.Fatal("expected error on duplicate email registration")
	}

	var appErr *httpx.AppError
	if !errors.As(err, &appErr) || appErr.Code != "email_taken" {
		t.Fatalf("expected email_taken code, got: %v", err)
	}
}
