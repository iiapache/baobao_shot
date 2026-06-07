package mediaclient

import (
	"context"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

// Stub is an in-memory OSS cleanup client for dev and unit tests.
type Stub struct {
	mu   sync.Mutex
	jobs map[string]*DeleteJob
	now  func() time.Time
}

// NewStub returns an empty OSS cleanup stub.
func NewStub() *Stub {
	return &Stub{
		jobs: make(map[string]*DeleteJob),
		now:  time.Now,
	}
}

// EnqueueDeletes records pending delete jobs (async worker picks them up).
func (s *Stub) EnqueueDeletes(_ context.Context, reqs []DeleteRequest) ([]DeleteJob, error) {
	if len(reqs) == 0 {
		return nil, nil
	}
	now := s.now().UTC()
	out := make([]DeleteJob, 0, len(reqs))
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, req := range reqs {
		key := strings.TrimSpace(req.ObjectKey)
		if key == "" {
			continue
		}
		jobID := "oss_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12]
		job := &DeleteJob{
			JobID:     jobID,
			PostID:    req.PostID,
			ObjectKey: key,
			Region:    strings.TrimSpace(req.Region),
			Status:    JobStatusPending,
			CreatedAt: now,
			UpdatedAt: now,
		}
		s.jobs[jobID] = job
		out = append(out, cloneJob(job))
	}
	return out, nil
}

// ListJobs returns a snapshot of all tracked jobs.
func (s *Stub) ListJobs() []DeleteJob {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]DeleteJob, 0, len(s.jobs))
	for _, job := range s.jobs {
		out = append(out, cloneJob(job))
	}
	return out
}

// PendingCount returns jobs awaiting worker dispatch.
func (s *Stub) PendingCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	n := 0
	for _, job := range s.jobs {
		if job.Status == JobStatusPending {
			n++
		}
	}
	return n
}

// DispatchPending marks pending jobs as dispatched (simulates OSS DeleteObject call).
func (s *Stub) DispatchPending(limit int) int {
	if limit <= 0 {
		limit = len(s.jobs)
	}
	now := s.now().UTC()
	s.mu.Lock()
	defer s.mu.Unlock()
	dispatched := 0
	for _, job := range s.jobs {
		if job.Status != JobStatusPending {
			continue
		}
		job.Status = JobStatusDispatched
		job.UpdatedAt = now
		dispatched++
		if dispatched >= limit {
			break
		}
	}
	return dispatched
}

// ConfirmDispatched marks dispatched jobs as confirmed (simulates MNS/SQS delete event).
func (s *Stub) ConfirmDispatched(limit int) int {
	if limit <= 0 {
		limit = len(s.jobs)
	}
	now := s.now().UTC()
	s.mu.Lock()
	defer s.mu.Unlock()
	confirmed := 0
	for _, job := range s.jobs {
		if job.Status != JobStatusDispatched {
			continue
		}
		job.Status = JobStatusConfirmed
		job.UpdatedAt = now
		confirmed++
		if confirmed >= limit {
			break
		}
	}
	return confirmed
}

// SetNow overrides the stub clock (tests/dev).
func (s *Stub) SetNow(fn func() time.Time) {
	if fn != nil {
		s.now = fn
	}
}

func cloneJob(job *DeleteJob) DeleteJob {
	if job == nil {
		return DeleteJob{}
	}
	return *job
}
