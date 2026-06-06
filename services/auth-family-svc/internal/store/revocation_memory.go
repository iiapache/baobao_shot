package store

import (
	"context"
	"sync"
	"time"
)

// MemoryRevocationStore is an in-process blacklist for tests and dev fallback.
type MemoryRevocationStore struct {
	mu      sync.RWMutex
	entries map[string]time.Time
}

// NewMemoryRevocationStore creates an empty in-memory revocation store.
func NewMemoryRevocationStore() *MemoryRevocationStore {
	return &MemoryRevocationStore{entries: make(map[string]time.Time)}
}

// Revoke marks a token JTI as invalid until ttl elapses.
func (s *MemoryRevocationStore) Revoke(_ context.Context, jti string, ttl time.Duration) error {
	if jti == "" {
		return nil
	}
	if ttl <= 0 {
		ttl = time.Second
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.entries[jti] = time.Now().UTC().Add(ttl)
	return nil
}

// IsRevoked reports whether the JTI is currently blacklisted.
func (s *MemoryRevocationStore) IsRevoked(_ context.Context, jti string) (bool, error) {
	if jti == "" {
		return false, nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	exp, ok := s.entries[jti]
	if !ok {
		return false, nil
	}
	if time.Now().UTC().After(exp) {
		delete(s.entries, jti)
		return false, nil
	}
	return true, nil
}
