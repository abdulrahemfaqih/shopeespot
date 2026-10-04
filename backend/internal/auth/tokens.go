package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var (
	// ErrInvalidToken is returned when a JWT token cannot be validated.
	ErrInvalidToken = errors.New("token akses tidak valid")
	// ErrExpiredToken is returned when a JWT token has expired.
	ErrExpiredToken = errors.New("token akses telah kedaluwarsa")
)

// GenerateAccessToken creates a signed JWT HS256 token with subject, iat, and exp claims.
func GenerateAccessToken(userID uuid.UUID, secret []byte, ttl time.Duration, now time.Time) (string, int, error) {
	if len(secret) < 32 {
		return "", 0, fmt.Errorf("JWT secret minimal 32 byte")
	}

	expiresAt := now.Add(ttl)
	claims := jwt.RegisteredClaims{
		Subject:   userID.String(),
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(expiresAt),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signedToken, err := token.SignedString(secret)
	if err != nil {
		return "", 0, fmt.Errorf("gagal menandatangani JWT: %w", err)
	}

	expiresIn := int(ttl.Seconds())
	return signedToken, expiresIn, nil
}

// ValidateAccessToken parses and validates a signed JWT token, returning the user UUID.
func ValidateAccessToken(tokenString string, secret []byte) (uuid.UUID, error) {
	claims := &jwt.RegisteredClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("metode signing tidak diharapkan: %v", t.Header["alg"])
		}
		return secret, nil
	})

	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return uuid.Nil, ErrExpiredToken
		}
		return uuid.Nil, ErrInvalidToken
	}

	if !token.Valid || claims.Subject == "" {
		return uuid.Nil, ErrInvalidToken
	}

	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return uuid.Nil, ErrInvalidToken
	}

	return userID, nil
}

// GenerateRefreshToken generates a 32-byte cryptographically secure random token and its SHA256 hex hash.
func GenerateRefreshToken() (rawToken string, tokenHash string, err error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", "", fmt.Errorf("gagal menghasilkan byte acak: %w", err)
	}

	rawToken = base64.RawURLEncoding.EncodeToString(bytes)
	tokenHash = HashRefreshToken(rawToken)
	return rawToken, tokenHash, nil
}

// HashRefreshToken calculates the SHA-256 hex representation of a raw refresh token.
func HashRefreshToken(rawToken string) string {
	sum := sha256.Sum256([]byte(rawToken))
	return hex.EncodeToString(sum[:])
}
