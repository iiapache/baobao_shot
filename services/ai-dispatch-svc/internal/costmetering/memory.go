package costmetering

import (
	"context"
	"fmt"
	"sort"
	"sync"
	"time"
)

// MemoryStore is an in-memory cost_metering store for tests and local dev.
type MemoryStore struct {
	mu      sync.RWMutex
	records map[string]*Record
}

// NewMemoryStore creates an empty in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{records: make(map[string]*Record)}
}

// Insert adds a cost record.
func (s *MemoryStore) Insert(_ context.Context, record *Record) error {
	if record == nil || record.ID == "" {
		return fmt.Errorf("record id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.records[record.ID]; exists {
		return fmt.Errorf("record %s already exists", record.ID)
	}
	copyRecord := *record
	s.records[record.ID] = &copyRecord
	return nil
}

// ListByTaskID returns all records for a task ordered by reportedAt.
func (s *MemoryStore) ListByTaskID(_ context.Context, taskID string) ([]Record, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Record, 0)
	for _, rec := range s.records {
		if rec.TaskID == taskID {
			out = append(out, *rec)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].ReportedAt.Before(out[j].ReportedAt)
	})
	return out, nil
}

// ListByTimeRange returns records with reportedAt in [start, end).
func (s *MemoryStore) ListByTimeRange(_ context.Context, start, end time.Time) ([]Record, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Record, 0)
	for _, rec := range s.records {
		if !rec.ReportedAt.Before(start) && rec.ReportedAt.Before(end) {
			out = append(out, *rec)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].ReportedAt.Before(out[j].ReportedAt)
	})
	return out, nil
}

// Close is a no-op for memory store.
func (s *MemoryStore) Close(_ context.Context) error {
	return nil
}
