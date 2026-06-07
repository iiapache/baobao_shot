package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/audit-svc/internal/model"
	"github.com/lib/pq"
)

// PostgresStore implements Store backed by PostgreSQL.
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

func (s *PostgresStore) CreateAuditJob(ctx context.Context, job *model.AuditJob) error {
	reasons, err := json.Marshal(job.Reasons)
	if err != nil {
		return err
	}
	const q = `
INSERT INTO audit_jobs (id, kind, target_ref, status, result, reasons, vendor, region, created_at, completed_at)
VALUES ($1, $2, $3, $4, NULLIF($5, ''), $6::jsonb, NULLIF($7, ''), $8, $9, $10)`
	_, err = s.db.ExecContext(ctx, q,
		job.ID,
		string(job.Kind),
		job.TargetRef,
		string(job.Status),
		job.Result,
		string(reasons),
		job.Vendor,
		job.Region,
		job.CreatedAt.UTC(),
		nullTime(job.CompletedAt),
	)
	return err
}

func (s *PostgresStore) GetAuditJob(ctx context.Context, jobID string) (*model.AuditJob, error) {
	const q = `
SELECT id, kind, target_ref, status, COALESCE(result, ''), reasons, COALESCE(vendor, ''), region, created_at, completed_at
FROM audit_jobs
WHERE id = $1`
	row := s.db.QueryRowContext(ctx, q, jobID)
	job, err := scanAuditJob(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return job, err
}

func (s *PostgresStore) GetRejectedAuditJobByTargetRef(ctx context.Context, targetRef string) (*model.AuditJob, error) {
	const q = `
SELECT id, kind, target_ref, status, COALESCE(result, ''), reasons, COALESCE(vendor, ''), region, created_at, completed_at
FROM audit_jobs
WHERE target_ref = $1 AND status = $2
ORDER BY created_at DESC
LIMIT 1`
	row := s.db.QueryRowContext(ctx, q, targetRef, string(model.AuditStatusRejected))
	job, err := scanAuditJob(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return job, err
}

func (s *PostgresStore) UpdateAuditJob(ctx context.Context, job *model.AuditJob) error {
	reasons, err := json.Marshal(job.Reasons)
	if err != nil {
		return err
	}
	const q = `
UPDATE audit_jobs
SET status = $2, result = NULLIF($3, ''), reasons = $4::jsonb, vendor = NULLIF($5, ''), completed_at = $6
WHERE id = $1`
	res, err := s.db.ExecContext(ctx, q,
		job.ID,
		string(job.Status),
		job.Result,
		string(reasons),
		job.Vendor,
		nullTime(job.CompletedAt),
	)
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

func (s *PostgresStore) CreateAppeal(ctx context.Context, appeal *model.Appeal) error {
	const q = `
INSERT INTO appeals (id, audit_job_id, user_id, reason, status, created_at, resolved_at)
VALUES ($1, $2, $3, $4, $5, $6, $7)`
	_, err := s.db.ExecContext(ctx, q,
		appeal.ID,
		appeal.AuditJobID,
		appeal.UserID,
		appeal.Reason,
		string(appeal.Status),
		appeal.CreatedAt.UTC(),
		nullTime(appeal.ResolvedAt),
	)
	if err == nil {
		return nil
	}
	var pqErr *pq.Error
	if errors.As(err, &pqErr) && pqErr.Code == "23505" {
		return ErrDuplicateAppeal
	}
	return fmt.Errorf("insert appeal: %w", err)
}

func (s *PostgresStore) GetAppeal(ctx context.Context, appealID string) (*model.Appeal, error) {
	const q = `
SELECT id, audit_job_id, user_id, reason, status, created_at, resolved_at
FROM appeals
WHERE id = $1`
	row := s.db.QueryRowContext(ctx, q, appealID)
	appeal, err := scanAppeal(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return appeal, err
}

func (s *PostgresStore) GetAppealByAuditJob(ctx context.Context, auditJobID string) (*model.Appeal, error) {
	const q = `
SELECT id, audit_job_id, user_id, reason, status, created_at, resolved_at
FROM appeals
WHERE audit_job_id = $1
ORDER BY created_at DESC
LIMIT 1`
	row := s.db.QueryRowContext(ctx, q, auditJobID)
	appeal, err := scanAppeal(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return appeal, err
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanAuditJob(row rowScanner) (*model.AuditJob, error) {
	var job model.AuditJob
	var kind, status string
	var reasonsJSON []byte
	var completedAt sql.NullTime
	if err := row.Scan(
		&job.ID,
		&kind,
		&job.TargetRef,
		&status,
		&job.Result,
		&reasonsJSON,
		&job.Vendor,
		&job.Region,
		&job.CreatedAt,
		&completedAt,
	); err != nil {
		return nil, err
	}
	job.Kind = model.AuditKind(kind)
	job.Status = model.AuditStatus(status)
	if len(reasonsJSON) > 0 {
		_ = json.Unmarshal(reasonsJSON, &job.Reasons)
	}
	if completedAt.Valid {
		t := completedAt.Time.UTC()
		job.CompletedAt = &t
	}
	job.CreatedAt = job.CreatedAt.UTC()
	return &job, nil
}

func scanAppeal(row rowScanner) (*model.Appeal, error) {
	var appeal model.Appeal
	var status string
	var resolvedAt sql.NullTime
	if err := row.Scan(
		&appeal.ID,
		&appeal.AuditJobID,
		&appeal.UserID,
		&appeal.Reason,
		&status,
		&appeal.CreatedAt,
		&resolvedAt,
	); err != nil {
		return nil, err
	}
	appeal.Status = model.AppealStatus(status)
	if resolvedAt.Valid {
		t := resolvedAt.Time.UTC()
		appeal.ResolvedAt = &t
	}
	appeal.CreatedAt = appeal.CreatedAt.UTC()
	return &appeal, nil
}

func nullTime(v *time.Time) any {
	if v == nil {
		return nil
	}
	return v.UTC()
}

// ApplyMigrations runs embedded SQL migrations.
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
