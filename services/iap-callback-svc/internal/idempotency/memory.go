package idempotency

import (
	"context"
	"sync"
)

// MemoryStore is an in-process idempotency store for tests and dev.
type MemoryStore struct {
	mu    sync.Mutex
	seen  map[string]struct{}
}

// NewMemoryStore creates an empty memory idempotency store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{seen: make(map[string]struct{})}
}

// TryClaim records a notification UUID once.
func (s *MemoryStore) TryClaim(_ context.Context, notificationUUID string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.seen[notificationUUID]; ok {
		return false, nil
	}
	s.seen[notificationUUID] = struct{}{}
	return true, nil
}
