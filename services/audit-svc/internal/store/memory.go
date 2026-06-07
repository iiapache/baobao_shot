package store

import (
	"context"
	"sync"

	"github.com/baobao/audit-svc/internal/model"
)

// MemoryStore is an in-memory Store for dev and unit tests.
type MemoryStore struct {
	mu          sync.RWMutex
	auditJobs   map[string]*model.AuditJob
	appeals     map[string]*model.Appeal
	appealByJob map[string]string
}

// NewMemoryStore returns an empty in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		auditJobs:   make(map[string]*model.AuditJob),
		appeals:     make(map[string]*model.Appeal),
		appealByJob: make(map[string]string),
	}
}

func (s *MemoryStore) Ping(_ context.Context) error { return nil }

func (s *MemoryStore) CreateAuditJob(_ context.Context, job *model.AuditJob) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.auditJobs[job.ID] = cloneAuditJob(job)
	return nil
}

func (s *MemoryStore) GetAuditJob(_ context.Context, jobID string) (*model.AuditJob, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	job, ok := s.auditJobs[jobID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneAuditJob(job), nil
}

func (s *MemoryStore) GetRejectedAuditJobByTargetRef(_ context.Context, targetRef string) (*model.AuditJob, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var latest *model.AuditJob
	for _, job := range s.auditJobs {
		if job.TargetRef != targetRef || job.Status != model.AuditStatusRejected {
			continue
		}
		if latest == nil || job.CreatedAt.After(latest.CreatedAt) {
			latest = job
		}
	}
	if latest == nil {
		return nil, ErrNotFound
	}
	return cloneAuditJob(latest), nil
}

func (s *MemoryStore) UpdateAuditJob(_ context.Context, job *model.AuditJob) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.auditJobs[job.ID]; !ok {
		return ErrNotFound
	}
	s.auditJobs[job.ID] = cloneAuditJob(job)
	return nil
}

func (s *MemoryStore) CreateAppeal(_ context.Context, appeal *model.Appeal) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.appealByJob[appeal.AuditJobID]; exists {
		return ErrDuplicateAppeal
	}
	s.appeals[appeal.ID] = cloneAppeal(appeal)
	s.appealByJob[appeal.AuditJobID] = appeal.ID
	return nil
}

func (s *MemoryStore) GetAppeal(_ context.Context, appealID string) (*model.Appeal, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	appeal, ok := s.appeals[appealID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneAppeal(appeal), nil
}

func (s *MemoryStore) GetAppealByAuditJob(_ context.Context, auditJobID string) (*model.Appeal, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	appealID, ok := s.appealByJob[auditJobID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneAppeal(s.appeals[appealID]), nil
}

func cloneAuditJob(job *model.AuditJob) *model.AuditJob {
	if job == nil {
		return nil
	}
	out := *job
	if job.Reasons != nil {
		out.Reasons = append([]string(nil), job.Reasons...)
	}
	if job.CompletedAt != nil {
		t := *job.CompletedAt
		out.CompletedAt = &t
	}
	return &out
}

func cloneAppeal(appeal *model.Appeal) *model.Appeal {
	if appeal == nil {
		return nil
	}
	out := *appeal
	if appeal.ResolvedAt != nil {
		t := *appeal.ResolvedAt
		out.ResolvedAt = &t
	}
	return &out
}
