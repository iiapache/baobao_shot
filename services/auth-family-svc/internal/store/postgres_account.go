package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *PostgresStore) FindUserIncludingDeleted(ctx context.Context, userID string) (*model.User, error) {
	const q = `
SELECT id, apple_sub, phone, region, nickname, avatar_url, status,
       child_data_consent_at, created_at, updated_at, last_seen_at, deleted_at
FROM users
WHERE id = $1
LIMIT 1`

	row := s.db.QueryRowContext(ctx, q, userID)
	user, err := scanUser(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return user, err
}

func (s *PostgresStore) SoftDeleteUser(ctx context.Context, userID string, deletedAt time.Time) error {
	const q = `
UPDATE users
SET status = 'deleted', deleted_at = $2, updated_at = $2
WHERE id = $1 AND deleted_at IS NULL`

	res, err := s.db.ExecContext(ctx, q, userID, deletedAt.UTC())
	if err != nil {
		return fmt.Errorf("soft delete user: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		// Idempotent when already soft-deleted during grace period.
		var exists bool
		err := s.db.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)`, userID).Scan(&exists)
		if err != nil {
			return err
		}
		if !exists {
			return ErrNotFound
		}
	}
	return nil
}

func (s *PostgresStore) RestoreUser(ctx context.Context, userID string) error {
	const q = `
UPDATE users
SET status = 'active', deleted_at = NULL, updated_at = NOW()
WHERE id = $1`

	res, err := s.db.ExecContext(ctx, q, userID)
	if err != nil {
		return fmt.Errorf("restore user: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) GetDeletion(ctx context.Context, userID string) (*model.AccountDeletion, error) {
	const q = `
SELECT user_id, requested_at, scheduled_at, cancelled_at, completed_at
FROM account_deletions
WHERE user_id = $1`

	row := s.db.QueryRowContext(ctx, q, userID)
	return scanAccountDeletion(row)
}

func (s *PostgresStore) UpsertDeletion(ctx context.Context, userID string, requestedAt, scheduledAt time.Time) (*model.AccountDeletion, error) {
	const q = `
INSERT INTO account_deletions (user_id, requested_at, scheduled_at)
VALUES ($1, $2, $3)
ON CONFLICT (user_id) DO UPDATE
SET requested_at = EXCLUDED.requested_at,
    scheduled_at = EXCLUDED.scheduled_at,
    cancelled_at = NULL,
    completed_at = NULL
RETURNING user_id, requested_at, scheduled_at, cancelled_at, completed_at`

	row := s.db.QueryRowContext(ctx, q, userID, requestedAt.UTC(), scheduledAt.UTC())
	return scanAccountDeletion(row)
}

func (s *PostgresStore) CancelDeletion(ctx context.Context, userID string, cancelledAt time.Time) (*model.AccountDeletion, error) {
	const q = `
UPDATE account_deletions
SET cancelled_at = $2
WHERE user_id = $1
  AND cancelled_at IS NULL
  AND completed_at IS NULL
  AND scheduled_at >= $2
RETURNING user_id, requested_at, scheduled_at, cancelled_at, completed_at`

	row := s.db.QueryRowContext(ctx, q, userID, cancelledAt.UTC())
	record, err := scanAccountDeletion(row)
	if errors.Is(err, sql.ErrNoRows) {
		existing, getErr := s.GetDeletion(ctx, userID)
		if getErr != nil {
			return nil, ErrDeletionNotPending
		}
		if existing.CompletedAt != nil {
			return nil, ErrNotFound
		}
		if existing.CancelledAt != nil {
			return nil, ErrDeletionNotPending
		}
		if cancelledAt.After(existing.ScheduledAt) {
			return nil, ErrDeletionExpired
		}
		return nil, ErrDeletionNotPending
	}
	return record, err
}

func (s *PostgresStore) ListDueDeletions(ctx context.Context, before time.Time) ([]model.AccountDeletion, error) {
	const q = `
SELECT user_id, requested_at, scheduled_at, cancelled_at, completed_at
FROM account_deletions
WHERE cancelled_at IS NULL
  AND completed_at IS NULL
  AND scheduled_at <= $1`

	rows, err := s.db.QueryContext(ctx, q, before.UTC())
	if err != nil {
		return nil, fmt.Errorf("list due deletions: %w", err)
	}
	defer rows.Close()

	out := make([]model.AccountDeletion, 0)
	for rows.Next() {
		record, err := scanAccountDeletionRows(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *record)
	}
	return out, rows.Err()
}

func (s *PostgresStore) CompleteHardDeletion(ctx context.Context, userID string, completedAt time.Time) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	const markQ = `
UPDATE account_deletions
SET completed_at = $2
WHERE user_id = $1
  AND cancelled_at IS NULL
  AND completed_at IS NULL`

	res, err := tx.ExecContext(ctx, markQ, userID, completedAt.UTC())
	if err != nil {
		return fmt.Errorf("complete deletion record: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}

	const userQ = `
UPDATE users
SET status = 'deleted', deleted_at = $2, updated_at = $2
WHERE id = $1`

	if _, err := tx.ExecContext(ctx, userQ, userID, completedAt.UTC()); err != nil {
		return fmt.Errorf("hard delete user: %w", err)
	}
	return tx.Commit()
}

func (s *PostgresStore) CreateExportRequest(ctx context.Context, userID, exportID string, requestedAt time.Time) (*model.DataExportRequest, error) {
	const q = `
INSERT INTO data_export_requests (id, user_id, status, requested_at)
VALUES ($1, $2, 'pending', $3)
RETURNING id, user_id, status, requested_at, completed_at`

	row := s.db.QueryRowContext(ctx, q, exportID, userID, requestedAt.UTC())
	return scanExportRequest(row)
}

func (s *PostgresStore) GetPendingExport(ctx context.Context, userID string) (*model.DataExportRequest, error) {
	const q = `
SELECT id, user_id, status, requested_at, completed_at
FROM data_export_requests
WHERE user_id = $1
  AND status IN ('pending', 'processing')
ORDER BY requested_at DESC
LIMIT 1`

	row := s.db.QueryRowContext(ctx, q, userID)
	record, err := scanExportRequest(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return record, err
}

type accountDeletionScanner interface {
	Scan(dest ...any) error
}

func scanAccountDeletion(row accountDeletionScanner) (*model.AccountDeletion, error) {
	var (
		record      model.AccountDeletion
		cancelledAt sql.NullTime
		completedAt sql.NullTime
	)
	err := row.Scan(
		&record.UserID,
		&record.RequestedAt,
		&record.ScheduledAt,
		&cancelledAt,
		&completedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if cancelledAt.Valid {
		t := cancelledAt.Time.UTC()
		record.CancelledAt = &t
	}
	if completedAt.Valid {
		t := completedAt.Time.UTC()
		record.CompletedAt = &t
	}
	record.RequestedAt = record.RequestedAt.UTC()
	record.ScheduledAt = record.ScheduledAt.UTC()
	return &record, nil
}

func scanAccountDeletionRows(rows *sql.Rows) (*model.AccountDeletion, error) {
	return scanAccountDeletion(rows)
}

func scanExportRequest(row rowScanner) (*model.DataExportRequest, error) {
	var (
		record      model.DataExportRequest
		completedAt sql.NullTime
	)
	err := row.Scan(
		&record.ID,
		&record.UserID,
		&record.Status,
		&record.RequestedAt,
		&completedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if completedAt.Valid {
		t := completedAt.Time.UTC()
		record.CompletedAt = &t
	}
	record.RequestedAt = record.RequestedAt.UTC()
	return &record, nil
}
