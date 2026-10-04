package config

import (
	"os"
	"testing"
	"time"
)

func TestConfigLoadDefaults(t *testing.T) {
	// Clear relevant env vars
	os.Unsetenv("APP_ENV")
	os.Unsetenv("PORT")
	os.Unsetenv("DATABASE_URL")
	os.Unsetenv("JWT_SECRET")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("expected no error loading config, got: %v", err)
	}

	if cfg.Port != "3000" {
		t.Errorf("expected default Port 3000, got %s", cfg.Port)
	}
	if cfg.AppEnv != "development" {
		t.Errorf("expected default AppEnv development, got %s", cfg.AppEnv)
	}
	if len(cfg.JWTSecret) < 32 {
		t.Errorf("expected default JWTSecret >= 32 bytes, got %d", len(cfg.JWTSecret))
	}
	if cfg.AccessTokenTTL != 15*time.Minute {
		t.Errorf("expected default AccessTokenTTL 15m, got %v", cfg.AccessTokenTTL)
	}
	if cfg.RefreshTokenTTL != 720*time.Hour {
		t.Errorf("expected default RefreshTokenTTL 720h, got %v", cfg.RefreshTokenTTL)
	}
	if cfg.RefreshGrace != 60*time.Second {
		t.Errorf("expected default RefreshGrace 60s, got %v", cfg.RefreshGrace)
	}
	if cfg.BcryptCost != 12 {
		t.Errorf("expected default BcryptCost 12, got %d", cfg.BcryptCost)
	}
	if !cfg.RegistrationEnabled {
		t.Errorf("expected default RegistrationEnabled true, got %v", cfg.RegistrationEnabled)
	}
}

func TestConfigShortSecretError(t *testing.T) {
	os.Setenv("APP_ENV", "production")
	os.Setenv("JWT_SECRET", "too-short")
	defer func() {
		os.Unsetenv("APP_ENV")
		os.Unsetenv("JWT_SECRET")
	}()

	_, err := Load()
	if err == nil {
		t.Fatal("expected error for JWT_SECRET shorter than 32 characters, got nil")
	}
}
