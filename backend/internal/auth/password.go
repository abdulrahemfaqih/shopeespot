package auth

import (
	"errors"
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

const (
	// MinPasswordLength is the minimum allowed password length.
	MinPasswordLength = 8
	// DefaultBcryptCost is the default bcrypt hashing cost.
	DefaultBcryptCost = 12
)

var (
	// ErrPasswordTooShort is returned when password is less than 8 characters.
	ErrPasswordTooShort = errors.New("kata sandi minimal 8 karakter")
)

// HashPassword hashes a raw password using bcrypt.
func HashPassword(password string, cost int) (string, error) {
	if len(password) < MinPasswordLength {
		return "", ErrPasswordTooShort
	}
	if cost < bcrypt.MinCost || cost > bcrypt.MaxCost {
		cost = DefaultBcryptCost
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), cost)
	if err != nil {
		return "", fmt.Errorf("gagal membuat hash password: %w", err)
	}

	return string(hash), nil
}

// CheckPassword verifies whether a raw password matches the bcrypt hash.
func CheckPassword(hash, password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}
