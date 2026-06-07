package audit

import (
	"context"

	"github.com/baobao/audit-svc/internal/model"
)

// SyncRequest is the normalized synchronous audit input.
type SyncRequest struct {
	TargetRef string
	Region    string
	MediaType string
	ObjectKey string
	Text      string
}

// AuditPipeline audits content for one audit kind.
type AuditPipeline interface {
	Kind() model.AuditKind
	SyncAudit(ctx context.Context, req SyncRequest) (*model.AuditJob, error)
	EnqueueAsync(ctx context.Context, req SyncRequest) (*model.AuditJob, error)
}

// PipelineSet groups the three audit pipelines.
type PipelineSet struct {
	Input  AuditPipeline
	Output AuditPipeline
	UGC    AuditPipeline
}

// ForKind returns the pipeline for the given kind.
func (p PipelineSet) ForKind(kind model.AuditKind) (AuditPipeline, error) {
	switch kind {
	case model.AuditKindInput:
		if p.Input == nil {
			return nil, ErrUnknownKind
		}
		return p.Input, nil
	case model.AuditKindOutput:
		if p.Output == nil {
			return nil, ErrUnknownKind
		}
		return p.Output, nil
	case model.AuditKindUGC:
		if p.UGC == nil {
			return nil, ErrUnknownKind
		}
		return p.UGC, nil
	default:
		return nil, ErrUnknownKind
	}
}
