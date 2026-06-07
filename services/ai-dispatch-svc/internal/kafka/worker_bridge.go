package kafka

import (
	"context"
	"fmt"
)

// DispatchingProducer publishes to an inner producer and dispatches to subscribed consumer handlers.
type DispatchingProducer struct {
	inner    *StubProducer
	consumer *StubConsumer
}

// NewDispatchingProducer wires stub producer output into the stub consumer (local dev / tests).
func NewDispatchingProducer(inner *StubProducer, consumer *StubConsumer) *DispatchingProducer {
	return &DispatchingProducer{inner: inner, consumer: consumer}
}

// Publish records the message and immediately delivers it to consumer handlers.
func (p *DispatchingProducer) Publish(ctx context.Context, topic string, msg TaskMessage) error {
	if p == nil || p.inner == nil {
		return fmt.Errorf("producer not initialized")
	}
	if err := p.inner.Publish(ctx, topic, msg); err != nil {
		return err
	}
	if p.consumer == nil {
		return nil
	}
	payload, err := Encode(msg)
	if err != nil {
		return err
	}
	return p.consumer.Inject(ctx, topic, payload)
}

// Close closes the inner producer.
func (p *DispatchingProducer) Close() error {
	if p == nil || p.inner == nil {
		return nil
	}
	return p.inner.Close()
}

// Inner returns the recording stub producer for assertions.
func (p *DispatchingProducer) Inner() *StubProducer {
	if p == nil {
		return nil
	}
	return p.inner
}

// WorkerBridge subscribes Kafka topics to a worker submit function.
type WorkerBridge struct {
	consumer Consumer
	submit   func(ctx context.Context, topic string, msg TaskMessage) error
}

// NewWorkerBridge connects a consumer to a worker pool submit callback.
func NewWorkerBridge(consumer Consumer, submit func(ctx context.Context, topic string, msg TaskMessage) error) *WorkerBridge {
	return &WorkerBridge{consumer: consumer, submit: submit}
}

// Start registers handlers for ai.image and ai.video worker topics.
func (b *WorkerBridge) Start() error {
	if b == nil || b.consumer == nil || b.submit == nil {
		return fmt.Errorf("worker bridge not initialized")
	}
	return b.consumer.Subscribe([]string{TopicImage, TopicVideo}, func(ctx context.Context, topic string, msg TaskMessage) error {
		return b.submit(ctx, topic, msg)
	})
}

// Stop stops the underlying consumer.
func (b *WorkerBridge) Stop() error {
	if b == nil || b.consumer == nil {
		return nil
	}
	return b.consumer.Stop()
}
