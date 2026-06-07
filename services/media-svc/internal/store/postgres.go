package store

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/baobao/media-svc/internal/config"
	"github.com/baobao/media-svc/internal/model"
	_ "github.com/lib/pq"
)

// PostgresUploadStore persists upload metadata in PostgreSQL.
type PostgresUploadStore struct {
	db *sql.DB
}

// NewUploadStore selects memory or postgres storage from config.
func NewUploadStore(cfg *config.Config) (UploadStore, *sql.DB, error) {
	if cfg == nil || cfg.StorageBackend != "postgres" {
		return NewMemoryUploadStore(), nil, nil
	}
	if cfg.DatabaseURL == "" {
		return nil, nil, fmt.Errorf("DATABASE_URL required when STORAGE_BACKEND=postgres")
	}
	db, err := sql.Open("postgres", cfg.DatabaseURL)
	if err != nil {
		return nil, nil, fmt.Errorf("open postgres: %w", err)
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		return nil, nil, fmt.Errorf("postgres not ready: %w", err)
	}
	return &PostgresUploadStore{db: db}, db, nil
}

// CreateSession inserts a session and its items in one transaction.
func (s *PostgresUploadStore) CreateSession(ctx context.Context, session *model.UploadSession) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	const sessionQ = `
INSERT INTO upload_sessions (id, user_id, purpose, family_id, region, status, expires_at, created_at)
VALUES ($1, $2, $3, NULLIF($4, ''), $5, $6, $7, $8)`
	if _, err := tx.ExecContext(ctx, sessionQ,
		session.ID,
		session.UserID,
		string(session.Purpose),
		session.FamilyID,
		session.Region,
		string(session.Status),
		session.ExpiresAt.UTC(),
		session.CreatedAt.UTC(),
	); err != nil {
		return fmt.Errorf("insert upload session: %w", err)
	}

	const itemQ = `
INSERT INTO upload_items (session_id, client_ref, kind, mime, size_bytes, sha256, object_key)
VALUES ($1, $2, $3, $4, $5, $6, $7)`
	for _, item := range session.Items {
		if _, err := tx.ExecContext(ctx, itemQ,
			session.ID,
			item.ClientRef,
			nullString(item.Kind),
			nullString(item.Mime),
			nullInt64(item.Size),
			nullString(item.SHA256),
			item.ObjectKey,
		); err != nil {
			return fmt.Errorf("insert upload item: %w", err)
		}
	}
	return tx.Commit()
}

// GetSession loads one session and its items.
func (s *PostgresUploadStore) GetSession(ctx context.Context, uploadID string) (*model.UploadSession, error) {
	const sessionQ = `
SELECT id, user_id, purpose, COALESCE(family_id, ''), region, status, expires_at, created_at
FROM upload_sessions
WHERE id = $1`
	row := s.db.QueryRowContext(ctx, sessionQ, uploadID)

	var session model.UploadSession
	var purpose, status string
	if err := row.Scan(
		&session.ID,
		&session.UserID,
		&purpose,
		&session.FamilyID,
		&session.Region,
		&status,
		&session.ExpiresAt,
		&session.CreatedAt,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, err
	}
	session.Purpose = model.Purpose(purpose)
	session.Status = model.UploadStatus(status)

	const itemQ = `
SELECT client_ref, COALESCE(kind, ''), COALESCE(mime, ''), COALESCE(size_bytes, 0), COALESCE(sha256, ''), object_key
FROM upload_items
WHERE session_id = $1
ORDER BY id`
	rows, err := s.db.QueryContext(ctx, itemQ, uploadID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var item model.UploadItem
		if err := rows.Scan(&item.ClientRef, &item.Kind, &item.Mime, &item.Size, &item.SHA256, &item.ObjectKey); err != nil {
			return nil, err
		}
		session.Items = append(session.Items, item)
	}
	return &session, rows.Err()
}

// UpdateSession updates session status.
func (s *PostgresUploadStore) UpdateSession(ctx context.Context, session *model.UploadSession) error {
	const q = `UPDATE upload_sessions SET status = $2 WHERE id = $1`
	res, err := s.db.ExecContext(ctx, q, session.ID, string(session.Status))
	if err != nil {
		return err
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

func nullString(v string) any {
	if v == "" {
		return nil
	}
	return v
}

func nullInt64(v int64) any {
	if v == 0 {
		return nil
	}
	return v
}
