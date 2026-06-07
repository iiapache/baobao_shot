package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/baobao/credit-sub-ad-svc/internal/config"
	"github.com/baobao/credit-sub-ad-svc/internal/iapevent"
)

const TopicIAPEvents = "iap.events"

// Consumer processes iap.events from iap-callback-svc.
type Consumer struct {
	cfg     *config.Config
	handler *iapevent.Handler
}

// NewConsumer creates a consumer bound to the IAP event handler.
func NewConsumer(cfg *config.Config, handler *iapevent.Handler) *Consumer {
	return &Consumer{cfg: cfg, handler: handler}
}

// Start blocks until ctx is cancelled. When Kafka is disabled this is a no-op stub.
func (c *Consumer) Start(ctx context.Context) error {
	if c == nil || c.cfg == nil || !c.cfg.KafkaEnabled() {
		slog.Info("kafka consumer disabled", "reason", "KAFKA_BROKERS not set")
		return nil
	}
	slog.Info("kafka consumer stub started",
		"brokers", c.cfg.KafkaBrokers,
		"topic", c.cfg.KafkaTopic,
		"group", c.cfg.KafkaGroupID,
	)
	<-ctx.Done()
	slog.Info("kafka consumer stopped")
	return nil
}

// HandleMessage processes one Kafka message payload (used by tests and future real consumer).
func (c *Consumer) HandleMessage(ctx context.Context, payload []byte) error {
	if c == nil || c.handler == nil {
		return fmt.Errorf("consumer not initialized")
	}
	var evt iapevent.IAPEvent
	if err := json.Unmarshal(payload, &evt); err != nil {
		return fmt.Errorf("decode event: %w", err)
	}
	return c.handler.Handle(ctx, evt)
}
