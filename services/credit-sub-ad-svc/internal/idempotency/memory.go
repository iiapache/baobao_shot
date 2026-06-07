package idempotency

import (
	"context"
	"sync"
)

// MemoryStore is an in-process idempotency cache for unit tests.
type MemoryStore struct {
	mu      sync.RWMutex
	holds   map[string]string
	settled map[string]bool
}

// NewMemoryStore returns an empty memory idempotency store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		holds:   make(map[string]string),
		settled: make(map[string]bool),
	}
}

func (s *MemoryStore) GetHoldID(_ context.Context, refKind, refID string) (string, bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	holdID, ok := s.holds[holdKey(refKind, refID)]
	return holdID, ok, nil
}

func (s *MemoryStore) SaveHoldID(_ context.Context, refKind, refID, holdID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.holds[holdKey(refKind, refID)] = holdID
	return nil
}

func (s *MemoryStore) IsSettled(_ context.Context, refKind, refID string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.settled[settledKey(refKind, refID)], nil
}

func (s *MemoryStore) MarkSettled(_ context.Context, refKind, refID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.settled[settledKey(refKind, refID)] = true
	return nil
}
