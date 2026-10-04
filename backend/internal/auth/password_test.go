package auth

import (
	"testing"
)

func TestHashAndCheckPassword(t *testing.T) {
	password := "Secret123!"

	hash, err := HashPassword(password, 4) // low cost for fast unit tests
	if err != nil {
		t.Fatalf("unexpected hash error: %v", err)
	}

	if !CheckPassword(hash, password) {
		t.Fatal("expected password to match hash")
	}

	if CheckPassword(hash, "WrongPassword") {
		t.Fatal("expected incorrect password not to match hash")
	}
}

func TestHashPassword_TooShort(t *testing.T) {
	_, err := HashPassword("short", 4)
	if err == nil {
		t.Fatal("expected error for password shorter than 8 characters, got nil")
	}
}
