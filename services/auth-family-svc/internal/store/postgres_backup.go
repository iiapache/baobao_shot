package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *PostgresStore) UpsertBackupProvider(ctx context.Context, in UpsertBackupProviderInput) (*model.BackupProvider, error) {
	metadataJSON, err := json.Marshal(cloneMetadataMap(in.Metadata))
	if err != nil {
		return nil, fmt.Errorf("marshal metadata: %w", err)
	}

	now := in.Now.UTC()
	if now.IsZero() {
		now = time.Now().UTC()
	}

	const q = `
INSERT INTO backup_providers (
    id, user_id, kind, access_token, refresh_token, expires_at,
    provider_account_id, metadata, status, created_at, updated_at
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9, $10, $10)
ON CONFLICT (user_id, kind) DO UPDATE SET
    access_token = EXCLUDED.access_token,
    refresh_token = EXCLUDED.refresh_token,
    expires_at = EXCLUDED.expires_at,
    provider_account_id = EXCLUDED.provider_account_id,
    metadata = EXCLUDED.metadata,
    status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at
RETURNING id, user_id, kind, access_token, refresh_token, expires_at,
          provider_account_id, metadata, status, created_at, updated_at`

	row := s.db.QueryRowContext(
		ctx,
		q,
		in.ID,
		in.UserID,
		in.Kind,
		in.AccessToken,
		nullString(in.RefreshToken),
		nullTimePtr(in.ExpiresAt),
		nullString(in.ProviderAccountID),
		string(metadataJSON),
		string(in.Status),
		now,
	)
	return scanBackupProvider(row)
}

func (s *PostgresStore) ListBackupProviders(ctx context.Context, userID string) ([]model.BackupProvider, error) {
	const q = `
SELECT id, user_id, kind, access_token, refresh_token, expires_at,
       provider_account_id, metadata, status, created_at, updated_at
FROM backup_providers
WHERE user_id = $1 AND status = 'active'
ORDER BY created_at ASC`

	rows, err := s.db.QueryContext(ctx, q, userID)
	if err != nil {
		return nil, fmt.Errorf("list backup providers: %w", err)
	}
	defer rows.Close()

	items := make([]model.BackupProvider, 0)
	for rows.Next() {
		provider, err := scanBackupProvider(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, *provider)
	}
	return items, rows.Err()
}

func (s *PostgresStore) DeleteBackupProvider(ctx context.Context, userID, providerID string) error {
	const q = `DELETE FROM backup_providers WHERE id = $1 AND user_id = $2`
	res, err := s.db.ExecContext(ctx, q, providerID, userID)
	if err != nil {
		return fmt.Errorf("delete backup provider: %w", err)
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

func (s *PostgresStore) GetBackupStatus(ctx context.Context, userID string) (*model.BackupStatus, error) {
	const q = `
SELECT user_id, last_success_at, last_attempt_at, failure_count, last_error_code, updated_at
FROM backup_status
WHERE user_id = $1`

	row := s.db.QueryRowContext(ctx, q, userID)
	status, err := scanBackupStatus(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return status, err
}

func (s *PostgresStore) UpsertBackupStatus(ctx context.Context, in UpsertBackupStatusInput) (*model.BackupStatus, error) {
	now := in.Now.UTC()
	if now.IsZero() {
		now = time.Now().UTC()
	}
	attemptedAt := in.AttemptedAt.UTC()

	var q string
	var args []any
	if in.Success {
		q = `
INSERT INTO backup_status (user_id, last_success_at, last_attempt_at, failure_count, last_error_code, updated_at)
VALUES ($1, $2, $2, 0, NULL, $3)
ON CONFLICT (user_id) DO UPDATE SET
    last_success_at = EXCLUDED.last_success_at,
    last_attempt_at = EXCLUDED.last_attempt_at,
    failure_count = 0,
    last_error_code = NULL,
    updated_at = EXCLUDED.updated_at
RETURNING user_id, last_success_at, last_attempt_at, failure_count, last_error_code, updated_at`
		args = []any{in.UserID, attemptedAt, now}
	} else {
		q = `
INSERT INTO backup_status (user_id, last_attempt_at, failure_count, last_error_code, updated_at)
VALUES ($1, $2, 1, $3, $4)
ON CONFLICT (user_id) DO UPDATE SET
    last_attempt_at = EXCLUDED.last_attempt_at,
    failure_count = backup_status.failure_count + 1,
    last_error_code = EXCLUDED.last_error_code,
    updated_at = EXCLUDED.updated_at
RETURNING user_id, last_success_at, last_attempt_at, failure_count, last_error_code, updated_at`
		args = []any{in.UserID, attemptedAt, nullString(in.ErrorCode), now}
	}

	row := s.db.QueryRowContext(ctx, q, args...)
	return scanBackupStatus(row)
}

func scanBackupProvider(row rowScanner) (*model.BackupProvider, error) {
	var (
		provider          model.BackupProvider
		refreshToken      sql.NullString
		expiresAt         sql.NullTime
		providerAccountID sql.NullString
		metadataRaw       []byte
		status            string
	)

	err := row.Scan(
		&provider.ID,
		&provider.UserID,
		&provider.Kind,
		&provider.AccessToken,
		&refreshToken,
		&expiresAt,
		&providerAccountID,
		&metadataRaw,
		&status,
		&provider.CreatedAt,
		&provider.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	provider.Status = model.BackupProviderStatus(status)
	if refreshToken.Valid {
		provider.RefreshToken = &refreshToken.String
	}
	if expiresAt.Valid {
		t := expiresAt.Time.UTC()
		provider.ExpiresAt = &t
	}
	if providerAccountID.Valid {
		provider.ProviderAccountID = &providerAccountID.String
	}
	if len(metadataRaw) > 0 {
		_ = json.Unmarshal(metadataRaw, &provider.Metadata)
	}
	if provider.Metadata == nil {
		provider.Metadata = map[string]string{}
	}

	provider.CreatedAt = provider.CreatedAt.UTC()
	provider.UpdatedAt = provider.UpdatedAt.UTC()
	return &provider, nil
}

func scanBackupStatus(row rowScanner) (*model.BackupStatus, error) {
	var (
		status        model.BackupStatus
		lastSuccessAt sql.NullTime
		lastAttemptAt sql.NullTime
		lastErrorCode sql.NullString
	)

	err := row.Scan(
		&status.UserID,
		&lastSuccessAt,
		&lastAttemptAt,
		&status.FailureCount,
		&lastErrorCode,
		&status.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	if lastSuccessAt.Valid {
		t := lastSuccessAt.Time.UTC()
		status.LastSuccessAt = &t
	}
	if lastAttemptAt.Valid {
		t := lastAttemptAt.Time.UTC()
		status.LastAttemptAt = &t
	}
	if lastErrorCode.Valid {
		status.LastErrorCode = &lastErrorCode.String
	}
	status.UpdatedAt = status.UpdatedAt.UTC()
	return &status, nil
}
