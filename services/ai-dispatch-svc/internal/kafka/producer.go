package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
)

// Producer publishes AI task messages to internal worker topics.
type Producer interface {
	Publish(ctx context.Context, topic string, msg TaskMessage) error
	Close() error
}

// StubProducer records published messages in memory for tests and local dev.
type StubProducer struct {
	mu       sync.Mutex
	messages map[string][]TaskMessage
	closed   bool
}

// NewStubProducer creates an in-memory Kafka producer stub.
func NewStubProducer() *StubProducer {
	return &StubProducer{messages: make(map[string][]TaskMessage)}
}

// Publish appends a message to the in-memory topic buffer.
func (p *StubProducer) Publish(_ context.Context, topic string, msg TaskMessage) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.closed {
		return fmt.Errorf("producer closed")
	}
	p.messages[topic] = append(p.messages[topic], msg)
	return nil
}

// Messages returns a copy of messages published to topic.
func (p *StubProducer) Messages(topic string) []TaskMessage {
	p.mu.Lock()
	defer p.mu.Unlock()
	src := p.messages[topic]
	out := make([]TaskMessage, len(src))
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

// Encode serializes a task message to JSON bytes.
func Encode(msg TaskMessage) ([]byte, error) {
	return json.Marshal(msg)
}
