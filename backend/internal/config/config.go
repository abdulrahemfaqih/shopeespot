package config

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all backend runtime configuration.
type Config struct {
	AppEnv              string
	Port                string
	DatabaseURL         string
	DatabaseURLDirect   string
	JWTSecret           []byte
	AccessTokenTTL      time.Duration
	RefreshTokenTTL     time.Duration
	RefreshGrace        time.Duration
	BcryptCost          int
	RegistrationEnabled bool
}

// Load loads configuration from environment variables, reading .env if present.
func Load() (*Config, error) {
	// Attempt to load .env from current working directory or relative project roots
	loadDotEnv(".env")
	loadDotEnv("backend/.env")
	loadDotEnv("../.env")
	loadDotEnv("../../.env")

	appEnv := getEnv("APP_ENV", "development")
	port := getEnv("PORT", "3000")
	dbURL := getEnv("DATABASE_URL", "")
	dbURLDirect := getEnv("DATABASE_URL_DIRECT", "")

	secretStr := getEnv("JWT_SECRET", "")
	if secretStr == "" && appEnv == "development" {
		secretStr = "development-secret-key-at-least-32-bytes-long!"
	}
	if len(secretStr) < 32 {
		return nil, fmt.Errorf("JWT_SECRET must be at least 32 characters long")
	}

	accessTTL, err := time.ParseDuration(getEnv("ACCESS_TOKEN_TTL", "15m"))
	if err != nil {
		accessTTL = 15 * time.Minute
	}

	refreshTTL, err := time.ParseDuration(getEnv("REFRESH_TOKEN_TTL", "720h"))
	if err != nil {
		refreshTTL = 720 * time.Hour
	}

	refreshGrace, err := time.ParseDuration(getEnv("REFRESH_GRACE", "60s"))
	if err != nil {
		refreshGrace = 60 * time.Second
	}

	bcryptCost, err := strconv.Atoi(getEnv("BCRYPT_COST", "12"))
	if err != nil || bcryptCost < 4 || bcryptCost > 31 {
		bcryptCost = 12
	}

	regEnabled := true
	if regVal := getEnv("REGISTRATION_ENABLED", "true"); regVal != "" {
		if parsed, err := strconv.ParseBool(regVal); err == nil {
			regEnabled = parsed
		}
	}

	return &Config{
		AppEnv:              appEnv,
		Port:                port,
		DatabaseURL:         dbURL,
		DatabaseURLDirect:   dbURLDirect,
		JWTSecret:           []byte(secretStr),
		AccessTokenTTL:      accessTTL,
		RefreshTokenTTL:     refreshTTL,
		RefreshGrace:        refreshGrace,
		BcryptCost:          bcryptCost,
		RegistrationEnabled: regEnabled,
	}, nil
}

func getEnv(key, defaultVal string) string {
	if val, ok := os.LookupEnv(key); ok {
		trimmed := strings.TrimSpace(val)
		if trimmed != "" {
			return trimmed
		}
	}
	return defaultVal
}

// loadDotEnv loads key-value pairs from a .env file without overriding existing env vars.
func loadDotEnv(filepath string) {
	file, err := os.Open(filepath)
	if err != nil {
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])

		// Strip optional surrounding quotes
		if len(val) >= 2 && ((val[0] == '"' && val[len(val)-1] == '"') || (val[0] == '\'' && val[len(val)-1] == '\'')) {
			val = val[1 : len(val)-1]
		}

		// Only set if not already set in OS environment
		if _, exists := os.LookupEnv(key); !exists {
			_ = os.Setenv(key, val)
		}
	}
}
