package audit

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
	"github.com/google/uuid"
)

// Service orchestrates audit pipelines, appeals, and async completion.
type Service struct {
	store     store.Store
	pipelines PipelineSet
	vendor    Vendor
	now       func() time.Time
	newID     func() string
}

// NewService wires the three pipelines with a stub vendor.
func NewService(st store.Store, vendor Vendor) *Service {
	if vendor == nil {
		vendor = StubVendor{}
	}
	return &Service{
		store: st,
		pipelines: PipelineSet{
			Input:  NewInputPipeline(st, vendor),
			Output: NewOutputPipeline(st, vendor),
			UGC:    NewUGCPipeline(st, vendor),
		},
		vendor: vendor,
		now:    time.Now,
		newID:  func() string { return "apl_" + uuid.NewString() },
	}
}

// SyncAudit runs a synchronous audit for input/output/ugc-text pipelines.
func (s *Service) SyncAudit(ctx context.Context, kind model.AuditKind, req SyncRequest) (*model.AuditJob, error) {
	if err := validateSyncRequest(kind, req); err != nil {
		return nil, err
	}
	pipeline, err := s.pipelines.ForKind(kind)
	if err != nil {
		return nil, err
	}
	return pipeline.SyncAudit(ctx, req)
}

// EnqueueUGCAsync creates a pending UGC media audit job for Kafka processing.
func (s *Service) EnqueueUGCAsync(ctx context.Context, req SyncRequest) (*model.AuditJob, error) {
	req.Region = normalizeRegion(req.Region)
	if req.TargetRef == "" {
		return nil, ErrMissingTargetRef
	}
	ugc, ok := s.pipelines.UGC.(*UGCPipeline)
	if !ok {
		return nil, ErrUnknownKind
	}
	return ugc.EnqueueAsync(ctx, req)
}

// CompleteUGCAsync completes a pending UGC media audit job from Kafka.
func (s *Service) CompleteUGCAsync(ctx context.Context, jobID string, req SyncRequest) (*model.AuditJob, error) {
	ugc, ok := s.pipelines.UGC.(*UGCPipeline)
	if !ok {
		return nil, ErrUnknownKind
	}
	return ugc.CompleteAsync(ctx, jobID, req)
}

// SubmitAppeal writes an appeal for a rejected audit job.
func (s *Service) SubmitAppeal(ctx context.Context, auditJobID, userID, reason string) (*model.Appeal, error) {
	return s.submitAppeal(ctx, auditJobID, userID, reason)
}

// SubmitAppealForTask resolves the latest rejected audit job for a task and submits an appeal.
func (s *Service) SubmitAppealForTask(ctx context.Context, taskID, userID, reason string) (*model.Appeal, error) {
	taskID = strings.TrimSpace(taskID)
	if taskID == "" {
		return nil, ErrMissingTargetRef
	}
	job, err := s.store.GetRejectedAuditJobByTargetRef(ctx, taskID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return nil, ErrAuditJobNotFound
		}
		return nil, err
	}
	return s.submitAppeal(ctx, job.ID, userID, reason)
}

func (s *Service) submitAppeal(ctx context.Context, auditJobID, userID, reason string) (*model.Appeal, error) {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return nil, ErrMissingAppealText
	}
	job, err := s.store.GetAuditJob(ctx, auditJobID)
	if err != nil {
		return nil, err
	}
	if job.Status != model.AuditStatusRejected {
		return nil, ErrAppealNotAllowed
	}
	if existing, err := s.store.GetAppealByAuditJob(ctx, auditJobID); err == nil && existing != nil {
		return nil, ErrAppealDuplicate
	} else if err != nil && err != store.ErrNotFound {
		return nil, err
	}

	now := s.now().UTC()
	appeal := &model.Appeal{
		ID:         s.newID(),
		AuditJobID: auditJobID,
		UserID:     userID,
		Reason:     reason,
		Status:     model.AppealStatusPending,
		CreatedAt:  now,
	}
	if err := s.store.CreateAppeal(ctx, appeal); err != nil {
		return nil, err
	}
	return appeal, nil
}

// GetAuditJob returns one audit job by id.
func (s *Service) GetAuditJob(ctx context.Context, jobID string) (*model.AuditJob, error) {
	return s.store.GetAuditJob(ctx, jobID)
}

func validateSyncRequest(kind model.AuditKind, req SyncRequest) error {
	switch kind {
	case model.AuditKindInput, model.AuditKindOutput, model.AuditKindUGC:
	default:
		return ErrInvalidKind
	}
	req.Region = normalizeRegion(req.Region)
	if req.Region == "" {
		return ErrInvalidRegion
	}
	if strings.TrimSpace(req.TargetRef) == "" {
		return ErrMissingTargetRef
	}
	return nil
}

func normalizeRegion(region string) string {
	return strings.ToLower(strings.TrimSpace(region))
}
