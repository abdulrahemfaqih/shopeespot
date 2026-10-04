package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	// ErrUserNotFound is returned when a user does not exist.
	ErrUserNotFound = errors.New("user_not_found")
	// ErrEmailAlreadyExists is returned when attempting to register an existing email.
	ErrEmailAlreadyExists = errors.New("email_already_exists")
	// ErrInvalidRefresh is returned when refresh token is missing, expired, or revoked.
	ErrInvalidRefresh = errors.New("invalid_refresh")
	// ErrReuseDetected is returned when an already-rotated token is used outside grace period.
	ErrReuseDetected = errors.New("reuse_detected")
	// ErrInvalidCredentials is returned when login credentials do not match.
	ErrInvalidCredentials = errors.New("invalid_credentials")
)

// Repository defines data access operations for authentication.
type Repository interface {
	CreateUser(ctx context.Context, user *User) error
	GetUserByEmail(ctx context.Context, email string) (*User, error)
	GetUserByID(ctx context.Context, id uuid.UUID) (*User, error)
	CreateRefreshToken(ctx context.Context, token *RefreshToken) error
	RotateRefreshToken(ctx context.Context, oldHash string, newToken *RefreshToken, grace time.Duration, now time.Time) (*RefreshToken, *User, error)
	RevokeFamilyByTokenHash(ctx context.Context, tokenHash string, revokedAt time.Time) error
}

type pgxRepository struct {
	pool *pgxpool.Pool
}

// NewRepository creates a PostgreSQL-backed auth repository.
func NewRepository(pool *pgxpool.Pool) Repository {
	return &pgxRepository{pool: pool}
}

func (r *pgxRepository) CreateUser(ctx context.Context, user *User) error {
	query := `
		INSERT INTO users (id, email, password_hash, created_at)
		VALUES ($1, $2, $3, $4)
	`
	_, err := r.pool.Exec(ctx, query, user.ID, user.Email, user.PasswordHash, user.CreatedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ErrEmailAlreadyExists
		}
		return fmt.Errorf("create user: %w", err)
	}
	return nil
}

func (r *pgxRepository) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	query := `
		SELECT id, email, password_hash, created_at
		FROM users
		WHERE lower(email) = lower($1)
	`
	row := r.pool.QueryRow(ctx, query, email)

	var u User
	err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &u.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("get user by email: %w", err)
	}
	return &u, nil
}

func (r *pgxRepository) GetUserByID(ctx context.Context, id uuid.UUID) (*User, error) {
	query := `
		SELECT id, email, password_hash, created_at
		FROM users
		WHERE id = $1
	`
	row := r.pool.QueryRow(ctx, query, id)

	var u User
	err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &u.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("get user by id: %w", err)
	}
	return &u, nil
}

func (r *pgxRepository) CreateRefreshToken(ctx context.Context, token *RefreshToken) error {
	query := `
		INSERT INTO refresh_tokens (id, user_id, family_id, token_hash, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.pool.Exec(ctx, query, token.ID, token.UserID, token.FamilyID, token.TokenHash, token.ExpiresAt, token.CreatedAt)
	if err != nil {
		return fmt.Errorf("create refresh token: %w", err)
	}
	return nil
}

func (r *pgxRepository) RotateRefreshToken(
	ctx context.Context,
	oldHash string,
	newToken *RefreshToken,
	grace time.Duration,
	now time.Time,
) (*RefreshToken, *User, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	oldToken, err := selectTokenForUpdate(ctx, tx, oldHash)
	if err != nil {
		return nil, nil, err
	}

	if oldToken.RevokedAt != nil || !now.Before(oldToken.ExpiresAt) {
		return nil, nil, ErrInvalidRefresh
	}

	if oldToken.RotatedAt != nil {
		elapsed := now.Sub(*oldToken.RotatedAt)
		if elapsed > grace {
			if err := revokeFamilyTx(ctx, tx, oldToken.FamilyID, now); err != nil {
				return nil, nil, err
			}
			if err := tx.Commit(ctx); err != nil {
				return nil, nil, fmt.Errorf("commit revoke tx: %w", err)
			}
			return nil, nil, ErrReuseDetected
		}
	} else {
		if err := markTokenRotatedTx(ctx, tx, oldToken.ID, now); err != nil {
			return nil, nil, err
		}
	}

	newToken.UserID = oldToken.UserID
	newToken.FamilyID = oldToken.FamilyID
	if err := insertRefreshTokenTx(ctx, tx, newToken); err != nil {
		return nil, nil, err
	}

	user, err := selectUserTx(ctx, tx, oldToken.UserID)
	if err != nil {
		return nil, nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, fmt.Errorf("commit tx: %w", err)
	}

	return newToken, user, nil
}

func selectTokenForUpdate(ctx context.Context, tx pgx.Tx, tokenHash string) (*RefreshToken, error) {
	query := `
		SELECT id, user_id, family_id, token_hash, expires_at, rotated_at, revoked_at, created_at
		FROM refresh_tokens
		WHERE token_hash = $1
		FOR UPDATE
	`
	var t RefreshToken
	err := tx.QueryRow(ctx, query, tokenHash).Scan(
		&t.ID, &t.UserID, &t.FamilyID, &t.TokenHash, &t.ExpiresAt, &t.RotatedAt, &t.RevokedAt, &t.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrInvalidRefresh
		}
		return nil, fmt.Errorf("select token for update: %w", err)
	}
	return &t, nil
}

func markTokenRotatedTx(ctx context.Context, tx pgx.Tx, tokenID uuid.UUID, rotatedAt time.Time) error {
	query := `UPDATE refresh_tokens SET rotated_at = $1 WHERE id = $2`
	_, err := tx.Exec(ctx, query, rotatedAt, tokenID)
	if err != nil {
		return fmt.Errorf("mark token rotated: %w", err)
	}
	return nil
}

func revokeFamilyTx(ctx context.Context, tx pgx.Tx, familyID uuid.UUID, revokedAt time.Time) error {
	query := `
		UPDATE refresh_tokens
		SET revoked_at = $1
		WHERE family_id = $2 AND revoked_at IS NULL
	`
	_, err := tx.Exec(ctx, query, revokedAt, familyID)
	if err != nil {
		return fmt.Errorf("revoke family tx: %w", err)
	}
	return nil
}

func insertRefreshTokenTx(ctx context.Context, tx pgx.Tx, token *RefreshToken) error {
	query := `
		INSERT INTO refresh_tokens (id, user_id, family_id, token_hash, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := tx.Exec(ctx, query, token.ID, token.UserID, token.FamilyID, token.TokenHash, token.ExpiresAt, token.CreatedAt)
	if err != nil {
		return fmt.Errorf("insert refresh token: %w", err)
	}
	return nil
}

func selectUserTx(ctx context.Context, tx pgx.Tx, userID uuid.UUID) (*User, error) {
	query := `SELECT id, email, password_hash, created_at FROM users WHERE id = $1`
	var u User
	err := tx.QueryRow(ctx, query, userID).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("select user tx: %w", err)
	}
	return &u, nil
}

func (r *pgxRepository) RevokeFamilyByTokenHash(ctx context.Context, tokenHash string, revokedAt time.Time) error {
	query := `
		UPDATE refresh_tokens
		SET revoked_at = $1
		WHERE family_id = (SELECT family_id FROM refresh_tokens WHERE token_hash = $2)
		  AND revoked_at IS NULL
	`
	_, err := r.pool.Exec(ctx, query, revokedAt, tokenHash)
	if err != nil {
		return fmt.Errorf("revoke family by token hash: %w", err)
	}
	return nil
}
