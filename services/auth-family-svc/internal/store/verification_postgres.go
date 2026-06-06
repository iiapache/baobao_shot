package store

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/lib/pq"
)

// PostgresVerificationStore persists SMS codes in PostgreSQL.
type PostgresVerificationStore struct {
	db *sql.DB
}

// NewPostgresVerificationStore wraps an existing connection pool.
func NewPostgresVerificationStore(db *sql.DB) *PostgresVerificationStore {
	return &PostgresVerificationStore{db: db}
}

func (s *PostgresVerificationStore) SaveCode(ctx context.Context, phone, region, code string, sentAt, expiresAt time.Time) error {
	const q = `
INSERT INTO phone_verification_codes (phone, region, code_hash, created_at, expires_at)
VALUES ($1, $2, $3, $4, $5)`
	_, err := s.db.ExecContext(ctx, q, phone, region, hashCode(code), sentAt.UTC(), expiresAt.UTC())
	return err
}

func (s *PostgresVerificationStore) VerifyAndConsume(ctx context.Context, phone, region, code string, now time.Time) error {
	const q = `
SELECT id, code_hash, expires_at, consumed_at
FROM phone_verification_codes
WHERE phone = $1 AND region = $2 AND consumed_at IS NULL
ORDER BY created_at DESC
LIMIT 1`

	var (
		id        int64
		codeHash  string
		expiresAt time.Time
		consumed  sql.NullTime
	)
	err := s.db.QueryRowContext(ctx, q, phone, region).Scan(&id, &codeHash, &expiresAt, &consumed)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrVerificationNotFound
	}
	if err != nil {
		return fmt.Errorf("query verification code: %w", err)
	}
	if now.UTC().After(expiresAt.UTC()) {
		return ErrVerificationExpired
	}
	if codeHash != hashCode(code) {
		return ErrVerificationMismatch
	}

	const consume = `UPDATE phone_verification_codes SET consumed_at = $2 WHERE id = $1`
	if _, err := s.db.ExecContext(ctx, consume, id, now.UTC()); err != nil {
		return fmt.Errorf("consume verification code: %w", err)
	}
	return nil
}

func (s *PostgresVerificationStore) LastSentAt(ctx context.Context, phone, region string) (time.Time, bool, error) {
	const q = `
SELECT created_at
FROM phone_verification_codes
WHERE phone = $1 AND region = $2
ORDER BY created_at DESC
LIMIT 1`

	var createdAt time.Time
	err := s.db.QueryRowContext(ctx, q, phone, region).Scan(&createdAt)
	if errors.Is(err, sql.ErrNoRows) {
		return time.Time{}, false, nil
	}
	if err != nil {
		return time.Time{}, false, err
	}
	return createdAt.UTC(), true, nil
}

func hashCode(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}

// FindByPhone and CreatePhoneUser for PostgresStore

func (s *PostgresStore) FindByPhone(ctx context.Context, phone, region string) (*model.User, error) {
	const q = `
SELECT id, apple_sub, phone, region, nickname, avatar_url, status,
       child_data_consent_at, created_at, updated_at, last_seen_at, deleted_at
FROM users
WHERE phone = $1 AND region = $2 AND deleted_at IS NULL
LIMIT 1`

	row := s.db.QueryRowContext(ctx, q, phone, region)
	user, err := scanUser(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return user, err
}

func (s *PostgresStore) CreatePhoneUser(ctx context.Context, in CreatePhoneUserInput) (*model.User, error) {
	const q = `
INSERT INTO users (id, phone, region, nickname, status, created_at, updated_at, last_seen_at)
VALUES ($1, $2, $3, $4, 'active', NOW(), NOW(), NOW())
RETURNING id, apple_sub, phone, region, nickname, avatar_url, status,
          child_data_consent_at, created_at, updated_at, last_seen_at, deleted_at`

	row := s.db.QueryRowContext(ctx, q, in.ID, in.Phone, in.Region, in.Nickname)
	user, err := scanUser(row)
	if err == nil {
		return user, nil
	}
	var pqErr *pq.Error
	if errors.As(err, &pqErr) && pqErr.Code == "23505" {
		return nil, ErrDuplicatePhone
	}
	return nil, fmt.Errorf("insert phone user: %w", err)
}
