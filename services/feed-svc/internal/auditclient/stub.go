package auditclient

import (
	"context"
	"strings"
	"sync"

	"github.com/google/uuid"
)

// Stub is an in-memory audit client aligned with audit-svc marker rules.
type Stub struct {
	mu      sync.Mutex
	pending map[string]MediaAuditRequest
}

// NewStub returns an empty audit stub.
func NewStub() *Stub {
	return &Stub{pending: make(map[string]MediaAuditRequest)}
}

// AuditTextSync blocks publish when text contains known reject markers.
func (s *Stub) AuditTextSync(_ context.Context, req TextAuditRequest) (Result, error) {
	if reasons := detectRejectReasons(req.Text, "", ""); len(reasons) > 0 {
		return Result{Passed: false, Reasons: reasons}, nil
	}
	return Result{
		JobID:  "aud_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12],
		Passed: true,
	}, nil
}

// EnqueueMediaAsync records a pending media audit job (completed by Kafka in production).
func (s *Stub) EnqueueMediaAsync(_ context.Context, req MediaAuditRequest) (Result, error) {
	jobID := "aud_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12]
	s.mu.Lock()
	s.pending[jobID] = req
	s.mu.Unlock()
	return Result{JobID: jobID, Passed: true}, nil
}

// CompleteMedia resolves a pending async job (test/dev helper).
func (s *Stub) CompleteMedia(jobID string) Result {
	s.mu.Lock()
	req, ok := s.pending[jobID]
	delete(s.pending, jobID)
	s.mu.Unlock()
	if !ok {
		return Result{JobID: jobID, Passed: true}
	}
	if reasons := detectRejectReasons("", req.ObjectKey, req.TargetRef); len(reasons) > 0 {
		return Result{JobID: jobID, Passed: false, Reasons: reasons}
	}
	return Result{JobID: jobID, Passed: true}
}

// PendingCount returns how many media jobs are still awaiting completion.
func (s *Stub) PendingCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.pending)
}

func detectRejectReasons(text, objectKey, targetRef string) []string {
	markers := []string{
		strings.ToLower(text),
		strings.ToLower(objectKey),
		strings.ToLower(targetRef),
	}
	for _, marker := range markers {
		if marker == "" {
			continue
		}
		if strings.Contains(marker, "reject_porn") || strings.Contains(marker, "违规色情") {
			return []string{"porn"}
		}
		if strings.Contains(marker, "reject_terror") || strings.Contains(marker, "违规暴恐") {
			return []string{"terrorism"}
		}
		if strings.Contains(marker, "reject_spam") || strings.Contains(marker, "违规文字") {
			return []string{"antispam"}
		}
		if strings.Contains(marker, "reject") {
			if strings.Contains(marker, ".mp4") || strings.Contains(marker, "video") {
				return []string{"porn", "terrorism"}
			}
			if text != "" {
				return []string{"antispam", "abuse"}
			}
			return []string{"porn"}
		}
	}
	return nil
}
