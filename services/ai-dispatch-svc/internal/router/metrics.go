package router

import (
	"sync"
	"time"
)

const defaultSuccessWindow = 5 * time.Minute

// MetricsStore tracks per-adapter queue depth and rolling success rate.
type MetricsStore struct {
	mu      sync.RWMutex
	window  time.Duration
	loads   map[string]int64
	outcomes map[string][]outcomeEvent
	clock   func() time.Time
}

type outcomeEvent struct {
	at      time.Time
	success bool
}

// NewMetricsStore creates a metrics store with a 5-minute success-rate window.
func NewMetricsStore() *MetricsStore {
	return &MetricsStore{
		window:   defaultSuccessWindow,
		loads:    make(map[string]int64),
		outcomes: make(map[string][]outcomeEvent),
		clock:    time.Now,
	}
}

// SetClock overrides the clock (tests only).
func (m *MetricsStore) SetClock(clock func() time.Time) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.clock = clock
}

// SetLoad sets the current queue depth for an adapter.
func (m *MetricsStore) SetLoad(adapterName string, depth int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.loads[adapterName] = depth
}

// Load returns the current queue depth (0 if unknown).
func (m *MetricsStore) Load(adapterName string) int64 {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.loads[adapterName]
}

// RecordOutcome appends a success/failure sample for sliding-window rate.
func (m *MetricsStore) RecordOutcome(adapterName string, success bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	now := m.clock()
	m.outcomes[adapterName] = append(m.outcomes[adapterName], outcomeEvent{at: now, success: success})
	m.pruneLocked(adapterName, now)
}

// SuccessRate returns the fraction of successes within the sliding window.
// Returns 1.0 when there are no samples (cold start optimism).
func (m *MetricsStore) SuccessRate(adapterName string) float64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	now := m.clock()
	events := m.pruneLocked(adapterName, now)
	if len(events) == 0 {
		return 1.0
	}
	successes := 0
	for _, e := range events {
		if e.success {
			successes++
		}
	}
	return float64(successes) / float64(len(events))
}

func (m *MetricsStore) pruneLocked(adapterName string, now time.Time) []outcomeEvent {
	cutoff := now.Add(-m.window)
	events := m.outcomes[adapterName]
	kept := events[:0]
	for _, e := range events {
		if !e.at.Before(cutoff) {
			kept = append(kept, e)
		}
	}
	m.outcomes[adapterName] = kept
	return kept
}
