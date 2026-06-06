package store

import (
	"context"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *MemoryStore) FindUserIncludingDeleted(_ context.Context, userID string) (*model.User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	user, ok := s.users[userID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneUser(user), nil
}

func (s *MemoryStore) SoftDeleteUser(_ context.Context, userID string, deletedAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	user, ok := s.users[userID]
	if !ok {
		return ErrNotFound
	}
	t := deletedAt.UTC()
	user.Status = model.UserStatusDeleted
	user.DeletedAt = &t
	user.UpdatedAt = t
	return nil
}

func (s *MemoryStore) RestoreUser(_ context.Context, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	user, ok := s.users[userID]
	if !ok {
		return ErrNotFound
	}
	now := time.Now().UTC()
	user.Status = model.UserStatusActive
	user.DeletedAt = nil
	user.UpdatedAt = now
	return nil
}

func (s *MemoryStore) GetDeletion(_ context.Context, userID string) (*model.AccountDeletion, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	record, ok := s.accountDeletions[userID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneAccountDeletion(record), nil
}

func (s *MemoryStore) UpsertDeletion(_ context.Context, userID string, requestedAt, scheduledAt time.Time) (*model.AccountDeletion, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.users[userID]; !ok {
		return nil, ErrNotFound
	}
	record := &model.AccountDeletion{
		UserID:      userID,
		RequestedAt: requestedAt.UTC(),
		ScheduledAt: scheduledAt.UTC(),
	}
	s.accountDeletions[userID] = record
	return cloneAccountDeletion(record), nil
}

func (s *MemoryStore) CancelDeletion(_ context.Context, userID string, cancelledAt time.Time) (*model.AccountDeletion, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	record, ok := s.accountDeletions[userID]
	if !ok {
		return nil, ErrNotFound
	}
	if record.CompletedAt != nil {
		return nil, ErrNotFound
	}
	if record.CancelledAt != nil {
		return nil, ErrDeletionNotPending
	}
	if cancelledAt.After(record.ScheduledAt) {
		return nil, ErrDeletionExpired
	}
	t := cancelledAt.UTC()
	record.CancelledAt = &t
	return cloneAccountDeletion(record), nil
}

func (s *MemoryStore) ListDueDeletions(_ context.Context, before time.Time) ([]model.AccountDeletion, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	cutoff := before.UTC()
	out := make([]model.AccountDeletion, 0)
	for _, record := range s.accountDeletions {
		if record.CancelledAt != nil || record.CompletedAt != nil {
			continue
		}
		if !record.ScheduledAt.After(cutoff) {
			out = append(out, *cloneAccountDeletion(record))
		}
	}
	return out, nil
}

func (s *MemoryStore) CompleteHardDeletion(_ context.Context, userID string, completedAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	record, ok := s.accountDeletions[userID]
	if !ok {
		return ErrNotFound
	}
	t := completedAt.UTC()
	record.CompletedAt = &t
	user, ok := s.users[userID]
	if !ok {
		return ErrNotFound
	}
	user.Status = model.UserStatusDeleted
	user.DeletedAt = &t
	user.UpdatedAt = t
	return nil
}

func (s *MemoryStore) CreateExportRequest(_ context.Context, userID, exportID string, requestedAt time.Time) (*model.DataExportRequest, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.users[userID]; !ok {
		return nil, ErrNotFound
	}
	record := &model.DataExportRequest{
		ID:          exportID,
		UserID:      userID,
		Status:      "pending",
		RequestedAt: requestedAt.UTC(),
	}
	s.exportRequests[exportID] = record
	s.pendingExports[userID] = exportID
	return cloneExportRequest(record), nil
}

func (s *MemoryStore) GetPendingExport(_ context.Context, userID string) (*model.DataExportRequest, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	exportID, ok := s.pendingExports[userID]
	if !ok {
		return nil, ErrNotFound
	}
	record, ok := s.exportRequests[exportID]
	if !ok || record.Status != "pending" && record.Status != "processing" {
		return nil, ErrNotFound
	}
	return cloneExportRequest(record), nil
}

func cloneAccountDeletion(d *model.AccountDeletion) *model.AccountDeletion {
	if d == nil {
		return nil
	}
	out := *d
	if d.CancelledAt != nil {
		t := *d.CancelledAt
		out.CancelledAt = &t
	}
	if d.CompletedAt != nil {
		t := *d.CompletedAt
		out.CompletedAt = &t
	}
	return &out
}

func cloneExportRequest(r *model.DataExportRequest) *model.DataExportRequest {
	if r == nil {
		return nil
	}
	out := *r
	if r.CompletedAt != nil {
		t := *r.CompletedAt
		out.CompletedAt = &t
	}
	return &out
}
