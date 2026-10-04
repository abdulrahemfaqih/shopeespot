package auth

import (
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAccessTokenGenerationAndValidation(t *testing.T) {
	secret := []byte("this-is-a-32-byte-secret-key-for-test!!")
	userID := uuid.New()
	now := time.Now()
	ttl := 15 * time.Minute

	token, expiresIn, err := GenerateAccessToken(userID, secret, ttl, now)
	if err != nil {
		t.Fatalf("failed to generate access token: %v", err)
	}

	if expiresIn != int(ttl.Seconds()) {
		t.Fatalf("expected expiresIn %d, got %d", int(ttl.Seconds()), expiresIn)
	}

	parsedID, err := ValidateAccessToken(token, secret)
	if err != nil {
		t.Fatalf("failed to validate token: %v", err)
	}

	if parsedID != userID {
		t.Fatalf("expected userID %s, got %s", userID, parsedID)
	}
}

func TestAccessToken_Expired(t *testing.T) {
	secret := []byte("this-is-a-32-byte-secret-key-for-test!!")
	userID := uuid.New()
	now := time.Now().Add(-1 * time.Hour)
	ttl := 10 * time.Minute // expired 50 minutes ago

	token, _, err := GenerateAccessToken(userID, secret, ttl, now)
	if err != nil {
		t.Fatalf("failed to generate token: %v", err)
	}

	_, err = ValidateAccessToken(token, secret)
	if !errors.Is(err, ErrExpiredToken) {
		t.Fatalf("expected ErrExpiredToken, got %v", err)
	}
}

func TestAccessToken_InvalidSignature(t *testing.T) {
	secret := []byte("this-is-a-32-byte-secret-key-for-test!!")
	wrongSecret := []byte("another-32-byte-secret-key-for-test!!!")
	userID := uuid.New()
	now := time.Now()

	token, _, err := GenerateAccessToken(userID, secret, 15*time.Minute, now)
	if err != nil {
		t.Fatalf("failed to generate token: %v", err)
	}

	_, err = ValidateAccessToken(token, wrongSecret)
	if !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("expected ErrInvalidToken, got %v", err)
	}
}

func TestRefreshTokenGenerationAndHash(t *testing.T) {
	rawToken, hash, err := GenerateRefreshToken()
	if err != nil {
		t.Fatalf("failed to generate refresh token: %v", err)
	}

	if rawToken == "" {
		t.Fatal("expected non-empty raw token")
	}

	expectedHash := HashRefreshToken(rawToken)
	if hash != expectedHash {
		t.Fatalf("expected hash %s, got %s", expectedHash, hash)
	}
}
