package auditclient

import (
	"context"
	"errors"
)

var (
	ErrMissingReason    = errors.New("appeal reason required")
	ErrAuditJobNotFound = errors.New("rejected audit job not found for task")
	ErrAppealNotAllowed = errors.New("appeal not allowed")
	ErrAppealDuplicate  = errors.New("appeal already exists")
	ErrUpstream         = errors.New("audit service unavailable")
)

// SubmitAppealRequest carries appeal submission to audit-svc.
type SubmitAppealRequest struct {
	TaskID string
	UserID string
	Reason string
}

// SubmitAppealResponse is the audit-svc appeal result.
type SubmitAppealResponse struct {
	AppealID   string
	AuditJobID string
	Status     string
}

// Client submits appeals to audit-svc.
type Client interface {
	SubmitAppealForTask(ctx context.Context, req SubmitAppealRequest) (*SubmitAppealResponse, error)
}
