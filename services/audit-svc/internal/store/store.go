package store

import (
	"context"
	"errors"

	"github.com/baobao/audit-svc/internal/model"
)

var ErrNotFound = errors.New("not found")

// AuditStore persists audit jobs.
type AuditStore interface {
	CreateAuditJob(ctx context.Context, job *model.AuditJob) error
	GetAuditJob(ctx context.Context, jobID string) (*model.AuditJob, error)
	GetRejectedAuditJobByTargetRef(ctx context.Context, targetRef string) (*model.AuditJob, error)
	UpdateAuditJob(ctx context.Context, job *model.AuditJob) error
}

// AppealStore persists appeals.
type AppealStore interface {
	CreateAppeal(ctx context.Context, appeal *model.Appeal) error
	GetAppeal(ctx context.Context, appealID string) (*model.Appeal, error)
	GetAppealByAuditJob(ctx context.Context, auditJobID string) (*model.Appeal, error)
}

// Store combines audit and appeal persistence.
type Store interface {
	AuditStore
	AppealStore
	Ping(ctx context.Context) error
}
