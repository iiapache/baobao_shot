package wspush

import (
	"context"
	"sync"
)

// Stub records published events for tests and no-op production wiring.
type Stub struct {
	mu     sync.Mutex
	events []Event
}

// NewStub returns an in-memory event recorder.
func NewStub() *Stub {
	return &Stub{events: make([]Event, 0)}
}

// PublishFeedEvent appends the event to the in-memory log.
func (s *Stub) PublishFeedEvent(_ context.Context, event Event) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.events = append(s.events, event)
	return nil
}

// Events returns a copy of recorded events.
func (s *Stub) Events() []Event {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Event, len(s.events))
	copy(out, s.events)
	return out
}

// Reset clears recorded events.
func (s *Stub) Reset() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.events = s.events[:0]
}
