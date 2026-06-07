package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
)

// Producer publishes IAP events to Kafka.
type Producer interface {
	Publish(ctx context.Context, topic string, evt IAPEvent) error
	Close() error
}

// StubProducer records published events in memory for tests and local dev.
type StubProducer struct {
	mu       sync.Mutex
	messages map[string][]IAPEvent
	closed   bool
}

// NewStubProducer creates an in-memory Kafka producer stub.
func NewStubProducer() *StubProducer {
	return &StubProducer{messages: make(map[string][]IAPEvent)}
}

// Publish appends an event to the in-memory topic buffer.
func (p *StubProducer) Publish(_ context.Context, topic string, evt IAPEvent) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.closed {
		return fmt.Errorf("producer closed")
	}
	p.messages[topic] = append(p.messages[topic], evt)
	return nil
}

// Messages returns a copy of events published to topic.
func (p *StubProducer) Messages(topic string) []IAPEvent {
	p.mu.Lock()
	defer p.mu.Unlock()
	src := p.messages[topic]
	out := make([]IAPEvent, len(src))
	copy(out, src)
	return out
}

// Close marks the producer as closed.
func (p *StubProducer) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.closed = true
	return nil
}

// Encode serializes an IAP event to JSON bytes.
func Encode(evt IAPEvent) ([]byte, error) {
	return json.Marshal(evt)
}
