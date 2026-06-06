package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/lib/pq"
)

// PostgresStore implements UserStore backed by PostgreSQL.
type PostgresStore struct {
	db *sql.DB
}

// NewPostgresStore wraps an existing *sql.DB connection pool.
func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{db: db}
}

func (s *PostgresStore) Ping(ctx context.Context) error {
	return s.db.PingContext(ctx)
}

func (s *PostgresStore) FindByAppleSub(ctx context.Context, appleSub string) (*model.User, error) {
	const q = `
SELECT id, apple_sub, phone, region, nickname, avatar_url, status,
       child_data_consent_at, created_at, updated_at, last_seen_at, deleted_at
FROM users
WHERE apple_sub = $1 AND deleted_at IS NULL
LIMIT 1`

	row := s.db.QueryRowContext(ctx, q, appleSub)
	user, err := scanUser(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return user, err
}

func (s *PostgresStore) CreateUser(ctx context.Context, in CreateUserInput) (*model.User, error) {
	const q = `
INSERT INTO users (id, apple_sub, region, nickname, status, created_at, updated_at, last_seen_at)
VALUES ($1, $2, $3, $4, 'active', NOW(), NOW(), NOW())
RETURNING id, apple_sub, phone, region, nickname, avatar_url, status,
          child_data_consent_at, created_at, updated_at, last_seen_at, deleted_at`

	row := s.db.QueryRowContext(ctx, q, in.ID, in.AppleSub, in.Region, in.Nickname)
	user, err := scanUser(row)
	if err == nil {
		return user, nil
	}
	var pqErr *pq.Error
	if errors.As(err, &pqErr) && pqErr.Code == "23505" && pqErr.Constraint == "uk_users_apple_sub" {
		return nil, ErrDuplicateAppleSub
	}
	return nil, fmt.Errorf("insert user: %w", err)
}

func (s *PostgresStore) TouchLastSeen(ctx context.Context, userID string) (*model.User, error) {
	const q = `
UPDATE users
SET last_seen_at = NOW(), updated_at = NOW()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id, apple_sub, phone, region, nickname, avatar_url, status,
          child_data_consent_at, created_at, updated_at, last_seen_at, deleted_at`

	row := s.db.QueryRowContext(ctx, q, userID)
	user, err := scanUser(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return user, err
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanUser(row rowScanner) (*model.User, error) {
	var (
		user              model.User
		appleSub          sql.NullString
		phone             sql.NullString
		avatarURL         sql.NullString
		childDataConsent  sql.NullTime
		deletedAt         sql.NullTime
		status            string
	)

	err := row.Scan(
		&user.ID,
		&appleSub,
		&phone,
		&user.Region,
		&user.Nickname,
		&avatarURL,
		&status,
		&childDataConsent,
		&user.CreatedAt,
		&user.UpdatedAt,
		&user.LastSeenAt,
		&deletedAt,
	)
	if err != nil {
		return nil, err
	}

	user.Status = model.UserStatus(status)
	if appleSub.Valid {
		user.AppleSub = &appleSub.String
	}
	if phone.Valid {
		user.Phone = &phone.String
	}
	if avatarURL.Valid {
		user.AvatarURL = &avatarURL.String
	}
	if childDataConsent.Valid {
		t := childDataConsent.Time.UTC()
		user.ChildDataConsentAt = &t
	}
	if deletedAt.Valid {
		t := deletedAt.Time.UTC()
		user.DeletedAt = &t
	}

	user.CreatedAt = user.CreatedAt.UTC()
	user.UpdatedAt = user.UpdatedAt.UTC()
	user.LastSeenAt = user.LastSeenAt.UTC()
	return &user, nil
}

// ApplyMigrations runs embedded SQL migrations (001_users.up.sql).
func ApplyMigrations(ctx context.Context, db *sql.DB, sql string) error {
	if _, err := db.ExecContext(ctx, sql); err != nil {
		return fmt.Errorf("apply migration: %w", err)
	}
	return nil
}

// WaitForPostgres pings until the database is reachable or timeout elapses.
func WaitForPostgres(ctx context.Context, db *sql.DB) error {
	deadline, ok := ctx.Deadline()
	if !ok {
		deadline = time.Now().Add(10 * time.Second)
	}
	for time.Now().Before(deadline) {
		if err := db.PingContext(ctx); err == nil {
			return nil
		}
		time.Sleep(200 * time.Millisecond)
	}
	return db.PingContext(ctx)
}
