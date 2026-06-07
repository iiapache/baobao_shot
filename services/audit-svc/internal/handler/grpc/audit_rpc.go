package grpc

import (
	"context"
	"fmt"

	"github.com/baobao/audit-svc/internal/audit"
	"github.com/baobao/audit-svc/internal/model"
)

// SyncAuditRequest mirrors the future protobuf SyncAudit RPC.
type SyncAuditRequest struct {
	Kind      string
	TargetRef string
	Region    string
	MediaType string
	ObjectKey string
	Text      string
}

// SyncAuditResponse mirrors the future protobuf SyncAudit RPC response.
type SyncAuditResponse struct {
	JobID   string
	Status  string
	Result  string
	Reasons []string
	Vendor  string
}

// SubmitAppealRequest mirrors the future protobuf SubmitAppeal RPC.
type SubmitAppealRequest struct {
	AuditJobID string
	TargetRef  string
	UserID     string
	Reason     string
}

// SubmitAppealResponse mirrors the future protobuf SubmitAppeal RPC response.
type SubmitAppealResponse struct {
	AppealID string
	Status   string
}

// AuditRPCServer implements synchronous audit and appeal RPC handlers.
type AuditRPCServer struct {
	service *audit.Service
}

// NewAuditRPCServer wires the audit service into gRPC handlers.
func NewAuditRPCServer(service *audit.Service) *AuditRPCServer {
	return &AuditRPCServer{service: service}
}

// SyncAudit handles synchronous input/output/ugc-text audits.
func (s *AuditRPCServer) SyncAudit(ctx context.Context, req *SyncAuditRequest) (*SyncAuditResponse, error) {
	if s == nil || s.service == nil {
		return nil, fmt.Errorf("audit service not configured")
	}
	if req == nil {
		return nil, fmt.Errorf("request required")
	}
	job, err := s.service.SyncAudit(ctx, model.AuditKind(req.Kind), audit.SyncRequest{
		TargetRef: req.TargetRef,
		Region:    req.Region,
		MediaType: req.MediaType,
		ObjectKey: req.ObjectKey,
		Text:      req.Text,
	})
	if err != nil {
		return nil, err
	}
	return &SyncAuditResponse{
		JobID:   job.ID,
		Status:  string(job.Status),
		Result:  job.Result,
		Reasons: append([]string(nil), job.Reasons...),
		Vendor:  job.Vendor,
	}, nil
}

// SubmitAppeal writes an appeal for a rejected audit job.
func (s *AuditRPCServer) SubmitAppeal(ctx context.Context, req *SubmitAppealRequest) (*SubmitAppealResponse, error) {
	if s == nil || s.service == nil {
		return nil, fmt.Errorf("audit service not configured")
	}
	if req == nil {
		return nil, fmt.Errorf("request required")
	}
	var (
		appeal *model.Appeal
		err    error
	)
	switch {
	case req.AuditJobID != "":
		appeal, err = s.service.SubmitAppeal(ctx, req.AuditJobID, req.UserID, req.Reason)
	case req.TargetRef != "":
		appeal, err = s.service.SubmitAppealForTask(ctx, req.TargetRef, req.UserID, req.Reason)
	default:
		return nil, fmt.Errorf("audit_job_id or target_ref required")
	}
	if err != nil {
		return nil, err
	}
	return &SubmitAppealResponse{
		AppealID: appeal.ID,
		Status:   string(appeal.Status),
	}, nil
}
