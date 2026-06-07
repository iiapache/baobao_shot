package audit

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
	"github.com/google/uuid"
)

type basePipeline struct {
	kind    model.AuditKind
	vendor  string
	store   store.AuditStore
	vendorC Vendor
	now     func() time.Time
	newID   func() string
}

func newBasePipeline(kind model.AuditKind, vendor string, st store.AuditStore, vendorC Vendor) *basePipeline {
	return &basePipeline{
		kind:    kind,
		vendor:  vendor,
		store:   st,
		vendorC: vendorC,
		now:     time.Now,
		newID:   func() string { return "aud_" + uuid.NewString() },
	}
}

func (p *basePipeline) Kind() model.AuditKind {
	return p.kind
}

func (p *basePipeline) SyncAudit(ctx context.Context, req SyncRequest) (*model.AuditJob, error) {
	job, err := p.createPending(ctx, req)
	if err != nil {
		return nil, err
	}
	return p.complete(ctx, job, req)
}

func (p *basePipeline) EnqueueAsync(ctx context.Context, req SyncRequest) (*model.AuditJob, error) {
	return p.createPending(ctx, req)
}

func (p *basePipeline) createPending(ctx context.Context, req SyncRequest) (*model.AuditJob, error) {
	now := p.now().UTC()
	job := &model.AuditJob{
		ID:        p.newID(),
		Kind:      p.kind,
		TargetRef: req.TargetRef,
		Status:    model.AuditStatusPending,
		Region:    req.Region,
		CreatedAt: now,
	}
	if err := p.store.CreateAuditJob(ctx, job); err != nil {
		return nil, err
	}
	return job, nil
}

func (p *basePipeline) vendorTimeout() time.Duration {
	switch p.kind {
	case model.AuditKindInput:
		return 3 * time.Second
	default:
		return 5 * time.Second
	}
}

func (p *basePipeline) complete(ctx context.Context, job *model.AuditJob, req SyncRequest) (*model.AuditJob, error) {
	auditCtx, cancel := context.WithTimeout(ctx, p.vendorTimeout())
	defer cancel()

	passed, reasons, err := p.vendorC.Audit(auditCtx, VendorRequest{
		Kind:      p.kind,
		TargetRef: req.TargetRef,
		Region:    req.Region,
		MediaType: req.MediaType,
		ObjectKey: req.ObjectKey,
		Text:      req.Text,
	})
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || auditCtx.Err() == context.DeadlineExceeded {
			return nil, fmt.Errorf("%w: %w", ErrVendorTimeout, err)
		}
		return nil, fmt.Errorf("vendor audit: %w", err)
	}

	to := model.AuditStatusPassed
	result := "passed"
	if !passed {
		to = model.AuditStatusRejected
		result = "rejected"
	}
	if err := ApplyTransition(job, to, result, reasons, p.vendor, p.now()); err != nil {
		return nil, err
	}
	if err := p.store.UpdateAuditJob(ctx, job); err != nil {
		return nil, err
	}
	return job, nil
}
