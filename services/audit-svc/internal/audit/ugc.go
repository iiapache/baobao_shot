package audit

import (
	"context"

	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
)

const ugcVendorName = "aliyun-green"

// UGCPipeline handles feed UGC audits (text sync, media async).
type UGCPipeline struct {
	*basePipeline
}

// NewUGCPipeline creates the UGC audit pipeline.
func NewUGCPipeline(st store.AuditStore, vendor Vendor) AuditPipeline {
	if vendor == nil {
		vendor = StubVendor{}
	}
	return &UGCPipeline{basePipeline: newBasePipeline(model.AuditKindUGC, ugcVendorName, st, vendor)}
}

// SyncAudit audits text synchronously and blocks publish when rejected.
func (p *UGCPipeline) SyncAudit(ctx context.Context, req SyncRequest) (*model.AuditJob, error) {
	if req.MediaType != "" && req.MediaType != "text" {
		return nil, ErrInvalidKind
	}
	return p.basePipeline.SyncAudit(ctx, req)
}

// EnqueueAsync creates a pending job for media that will be completed by Kafka worker.
func (p *UGCPipeline) EnqueueAsync(ctx context.Context, req SyncRequest) (*model.AuditJob, error) {
	return p.basePipeline.EnqueueAsync(ctx, req)
}

// CompleteAsync finishes a pending UGC media job (Kafka consumer path).
func (p *UGCPipeline) CompleteAsync(ctx context.Context, jobID string, req SyncRequest) (*model.AuditJob, error) {
	job, err := p.store.GetAuditJob(ctx, jobID)
	if err != nil {
		return nil, err
	}
	if job.Status != model.AuditStatusPending {
		return job, nil
	}
	return p.basePipeline.complete(ctx, job, req)
}
