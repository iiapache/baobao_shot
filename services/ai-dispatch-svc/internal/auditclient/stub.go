package auditclient

import (
	"context"
	"strings"
	"sync"

	"github.com/google/uuid"
)

// Stub is an in-memory audit-svc client for tests and local dev.
type Stub struct {
	mu sync.Mutex
	// taskID -> rejected audit job id
	rejectedJobs map[string]string
	appeals      map[string]*SubmitAppealResponse
}

// NewStub returns an empty audit client stub.
func NewStub() *Stub {
	return &Stub{
		rejectedJobs: make(map[string]string),
		appeals:      make(map[string]*SubmitAppealResponse),
	}
}

// RegisterRejectedJob records a rejected audit job for a task id.
func (s *Stub) RegisterRejectedJob(taskID, auditJobID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rejectedJobs[taskID] = auditJobID
}

// SubmitAppealForTask creates a pending appeal for a registered rejected job.
func (s *Stub) SubmitAppealForTask(_ context.Context, req SubmitAppealRequest) (*SubmitAppealResponse, error) {
	reason := strings.TrimSpace(req.Reason)
	if reason == "" {
		return nil, ErrMissingReason
	}
	if strings.TrimSpace(req.TaskID) == "" {
		return nil, ErrAuditJobNotFound
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	auditJobID, ok := s.rejectedJobs[req.TaskID]
	if !ok {
		return nil, ErrAuditJobNotFound
	}
	if _, exists := s.appeals[req.TaskID]; exists {
		return nil, ErrAppealDuplicate
	}

	resp := &SubmitAppealResponse{
		AppealID:   "apl_" + uuid.NewString(),
		AuditJobID: auditJobID,
		Status:     "pending",
	}
	s.appeals[req.TaskID] = resp
	return resp, nil
}
