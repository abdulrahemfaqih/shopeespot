package auth

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/abdulrahemfaqih/shopeespot/internal/httpx"
)

// Service defines auth business logic.
type Service interface {
	Register(ctx context.Context, req RegisterRequest) (*AuthResponse, error)
	Login(ctx context.Context, req LoginRequest) (*AuthResponse, error)
	Refresh(ctx context.Context, req RefreshRequest) (*AuthResponse, error)
	Logout(ctx context.Context, req LogoutRequest) error
	ValidateToken(tokenStr string) (uuid.UUID, error)
}

// ServiceConfig contains runtime settings for auth service.
type ServiceConfig struct {
	JWTSecret           []byte
	AccessTokenTTL      time.Duration
	RefreshTokenTTL     time.Duration
	RefreshGrace        time.Duration
	BcryptCost          int
	RegistrationEnabled bool
	NowFunc             func() time.Time
}

type authService struct {
	repo Repository
	cfg  ServiceConfig
}

// NewService creates a new auth service instance.
func NewService(repo Repository, cfg ServiceConfig) Service {
	if cfg.NowFunc == nil {
		cfg.NowFunc = time.Now
	}
	return &authService{
		repo: repo,
		cfg:  cfg,
	}
}

func (s *authService) Register(ctx context.Context, req RegisterRequest) (*AuthResponse, error) {
	if !s.cfg.RegistrationEnabled {
		return nil, httpx.NewAppError(403, "registration_disabled", "Pendaftaran akun dinonaktifkan.", nil)
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	hash, err := HashPassword(req.Password, s.cfg.BcryptCost)
	if err != nil {
		return nil, httpx.NewAppError(400, "bad_request", err.Error(), err)
	}

	now := s.cfg.NowFunc()
	user := &User{
		ID:           uuid.New(),
		Email:        email,
		PasswordHash: hash,
		CreatedAt:    now,
	}

	if err := s.repo.CreateUser(ctx, user); err != nil {
		if errors.Is(err, ErrEmailAlreadyExists) {
			return nil, httpx.NewAppError(409, "email_taken", "Email sudah terdaftar.", err)
		}
		return nil, err
	}

	return s.createSession(ctx, user, now)
}

func (s *authService) Login(ctx context.Context, req LoginRequest) (*AuthResponse, error) {
	email := strings.ToLower(strings.TrimSpace(req.Email))
	user, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		// Generic invalid credentials for any lookup failure
		return nil, httpx.NewAppError(401, "invalid_credentials", "Email atau kata sandi salah.", nil)
	}

	if !CheckPassword(user.PasswordHash, req.Password) {
		return nil, httpx.NewAppError(401, "invalid_credentials", "Email atau kata sandi salah.", nil)
	}

	now := s.cfg.NowFunc()
	return s.createSession(ctx, user, now)
}

func (s *authService) Refresh(ctx context.Context, req RefreshRequest) (*AuthResponse, error) {
	rawOldToken := strings.TrimSpace(req.RefreshToken)
	if rawOldToken == "" {
		return nil, httpx.NewAppError(401, "invalid_refresh", "Token penyegar tidak valid atau telah kedaluwarsa.", nil)
	}

	oldHash := HashRefreshToken(rawOldToken)
	now := s.cfg.NowFunc()

	newRaw, newHash, err := GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	newToken := &RefreshToken{
		ID:        uuid.New(),
		TokenHash: newHash,
		ExpiresAt: now.Add(s.cfg.RefreshTokenTTL),
		CreatedAt: now,
	}

	_, user, err := s.repo.RotateRefreshToken(ctx, oldHash, newToken, s.cfg.RefreshGrace, now)
	if err != nil {
		if errors.Is(err, ErrInvalidRefresh) {
			return nil, httpx.NewAppError(401, "invalid_refresh", "Token penyegar tidak valid atau telah kedaluwarsa.", err)
		}
		if errors.Is(err, ErrReuseDetected) {
			return nil, httpx.NewAppError(401, "reuse_detected", "Pemakaian ulang token terdeteksi. Sesi telah dicabut demi keamanan.", err)
		}
		return nil, err
	}

	accessToken, expiresIn, err := GenerateAccessToken(user.ID, s.cfg.JWTSecret, s.cfg.AccessTokenTTL, now)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: newRaw,
		ExpiresIn:    expiresIn,
		User: UserResponse{
			ID:    user.ID.String(),
			Email: user.Email,
		},
	}, nil
}

func (s *authService) Logout(ctx context.Context, req LogoutRequest) error {
	rawToken := strings.TrimSpace(req.RefreshToken)
	if rawToken == "" {
		return nil
	}

	tokenHash := HashRefreshToken(rawToken)
	now := s.cfg.NowFunc()
	return s.repo.RevokeFamilyByTokenHash(ctx, tokenHash, now)
}

func (s *authService) ValidateToken(tokenStr string) (uuid.UUID, error) {
	return ValidateAccessToken(tokenStr, s.cfg.JWTSecret)
}

func (s *authService) createSession(ctx context.Context, user *User, now time.Time) (*AuthResponse, error) {
	rawRefresh, refreshHash, err := GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	familyID := uuid.New()
	token := &RefreshToken{
		ID:        uuid.New(),
		UserID:    user.ID,
		FamilyID:  familyID,
		TokenHash: refreshHash,
		ExpiresAt: now.Add(s.cfg.RefreshTokenTTL),
		CreatedAt: now,
	}

	if err := s.repo.CreateRefreshToken(ctx, token); err != nil {
		return nil, err
	}

	accessToken, expiresIn, err := GenerateAccessToken(user.ID, s.cfg.JWTSecret, s.cfg.AccessTokenTTL, now)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: rawRefresh,
		ExpiresIn:    expiresIn,
		User: UserResponse{
			ID:    user.ID.String(),
			Email: user.Email,
		},
	}, nil
}
