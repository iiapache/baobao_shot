package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *PostgresStore) FindByID(ctx context.Context, userID string) (*model.User, error) {
	const q = `
SELECT id, apple_sub, phone, region, nickname, avatar_url, status,
       child_data_consent_at, created_at, updated_at, last_seen_at, deleted_at
FROM users
WHERE id = $1 AND deleted_at IS NULL
LIMIT 1`

	row := s.db.QueryRowContext(ctx, q, userID)
	user, err := scanUser(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return user, err
}

func (s *PostgresStore) RecordChildConsent(ctx context.Context, in RecordChildConsentInput) (*model.ChildConsent, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	const insertQ = `
INSERT INTO child_consents (user_id, version, agreed_at, ip, device_id)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (user_id, version) DO UPDATE
SET agreed_at = EXCLUDED.agreed_at,
    ip = EXCLUDED.ip,
    device_id = EXCLUDED.device_id
RETURNING user_id, version, agreed_at, ip, device_id`

	var record model.ChildConsent
	if err := tx.QueryRowContext(ctx, insertQ,
		in.UserID, in.Version, in.AgreedAt, in.IP, in.DeviceID,
	).Scan(&record.UserID, &record.Version, &record.AgreedAt, &record.IP, &record.DeviceID); err != nil {
		return nil, fmt.Errorf("insert child consent: %w", err)
	}

	const updateUserQ = `
UPDATE users
SET child_data_consent_at = $2, updated_at = NOW()
WHERE id = $1 AND deleted_at IS NULL`

	res, err := tx.ExecContext(ctx, updateUserQ, in.UserID, in.AgreedAt)
	if err != nil {
		return nil, fmt.Errorf("update user consent timestamp: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return nil, fmt.Errorf("rows affected: %w", err)
	}
	if n == 0 {
		return nil, ErrNotFound
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit tx: %w", err)
	}

	record.AgreedAt = record.AgreedAt.UTC()
	return &record, nil
}

func (s *PostgresStore) HasChildConsent(ctx context.Context, userID, version string) (bool, error) {
	const q = `SELECT 1 FROM child_consents WHERE user_id = $1 AND version = $2 LIMIT 1`
	var one int
	err := s.db.QueryRowContext(ctx, q, userID, version).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("query child consent: %w", err)
	}
	return true, nil
}
