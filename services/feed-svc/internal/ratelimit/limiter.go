package ratelimit

import (
	"sync"
	"time"
)

// Config defines sliding-window limits for an endpoint.
type Config struct {
	Window time.Duration
	Max    int
}

// SlidingWindow tracks event timestamps per key within configurable windows.
type SlidingWindow struct {
	mu     sync.Mutex
	events map[string][]time.Time
}

// NewSlidingWindow returns an empty limiter.
func NewSlidingWindow() *SlidingWindow {
	return &SlidingWindow{events: make(map[string][]time.Time)}
}

// Allow reports whether another event is permitted and records it when allowed.
func (l *SlidingWindow) Allow(key string, now time.Time, cfg Config) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	cutoff := now.Add(-cfg.Window)
	history := l.events[key]
	filtered := history[:0]
	for _, ts := range history {
		if ts.After(cutoff) {
			filtered = append(filtered, ts)
		}
	}
	if len(filtered) >= cfg.Max {
		l.events[key] = filtered
		return false
	}
	filtered = append(filtered, now)
	l.events[key] = filtered
	return true
}

// Count returns how many events fall within the window without recording.
func (l *SlidingWindow) Count(key string, now time.Time, window time.Duration) int {
	l.mu.Lock()
	defer l.mu.Unlock()
	cutoff := now.Add(-window)
	count := 0
	for _, ts := range l.events[key] {
		if ts.After(cutoff) {
			count++
		}
	}
	return count
}
