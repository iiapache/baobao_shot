package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
)

// Handler processes a consumed task message.
type Handler func(ctx context.Context, topic string, msg TaskMessage) error

// Consumer subscribes to internal worker topics.
type Consumer interface {
	Subscribe(topics []string, handler Handler) error
	Stop() error
}

// StubConsumer delivers messages registered via Inject for tests and local dev.
type StubConsumer struct {
	mu       sync.Mutex
	topics   map[string]Handler
	stopped  bool
}

// NewStubConsumer creates an in-memory Kafka consumer stub.
func NewStubConsumer() *StubConsumer {
	return &StubConsumer{topics: make(map[string]Handler)}
}

// Subscribe registers a handler for the given topics.
func (c *StubConsumer) Subscribe(topics []string, handler Handler) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.stopped {
		return fmt.Errorf("consumer stopped")
	}
	for _, topic := range topics {
		c.topics[topic] = handler
	}
	return nil
}

// Inject delivers a message to the registered handler (test helper).
func (c *StubConsumer) Inject(ctx context.Context, topic string, payload []byte) error {
	c.mu.Lock()
	handler, ok := c.topics[topic]
	stopped := c.stopped
	c.mu.Unlock()

	if stopped {
		return fmt.Errorf("consumer stopped")
	}
	if !ok {
		return fmt.Errorf("no handler for topic %s", topic)
	}

	var msg TaskMessage
	if err := json.Unmarshal(payload, &msg); err != nil {
		return fmt.Errorf("decode message: %w", err)
	}
	return handler(ctx, topic, msg)
}

// Stop marks the consumer as stopped.
func (c *StubConsumer) Stop() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.stopped = true
	return nil
}
