package store

import (
	"context"
	"sync"
	"time"
)

// MemoryVerificationStore stores verification codes in process memory.
type MemoryVerificationStore struct {
	mu     sync.Mutex
	codes  map[string]VerificationRecord // phone|region -> latest code
	sentAt map[string]time.Time
}

// NewMemoryVerificationStore returns an empty verification store.
func NewMemoryVerificationStore() *MemoryVerificationStore {
	return &MemoryVerificationStore{
		codes:  make(map[string]VerificationRecord),
		sentAt: make(map[string]time.Time),
	}
}

func (s *MemoryVerificationStore) SaveCode(_ context.Context, phone, region, code string, sentAt, expiresAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := phoneRegionKey(phone, region)
	sentAt = sentAt.UTC()
	s.codes[key] = VerificationRecord{
		Phone:     phone,
		Region:    region,
		Code:      code,
		CreatedAt: sentAt,
		ExpiresAt: expiresAt.UTC(),
	}
	s.sentAt[key] = sentAt
	return nil
}

func (s *MemoryVerificationStore) VerifyAndConsume(_ context.Context, phone, region, code string, now time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := phoneRegionKey(phone, region)
	rec, ok := s.codes[key]
	if !ok {
		return ErrVerificationNotFound
	}
	if now.UTC().After(rec.ExpiresAt) {
		delete(s.codes, key)
		return ErrVerificationExpired
	}
	if rec.Code != code {
		return ErrVerificationMismatch
	}
	delete(s.codes, key)
	return nil
}

func (s *MemoryVerificationStore) LastSentAt(_ context.Context, phone, region string) (time.Time, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	t, ok := s.sentAt[phoneRegionKey(phone, region)]
	return t, ok, nil
}
