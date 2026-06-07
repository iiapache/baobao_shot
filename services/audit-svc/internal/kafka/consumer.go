package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/baobao/audit-svc/internal/audit"
	"github.com/baobao/audit-svc/internal/config"
)

const (
	eventUGCAuditRequested = "ugc.audit.requested"
	eventUGCAuditComplete  = "ugc.audit.complete"
)

// UGCAuditEvent is a feed.events payload for async UGC media audits.
type UGCAuditEvent struct {
	EventType string `json:"eventType"`
	JobID     string `json:"jobId"`
	TargetRef string `json:"targetRef"`
	ObjectKey string `json:"objectKey"`
	Region    string `json:"region"`
	MediaType string `json:"mediaType"`
}

// Consumer is a Kafka consumer stub for async UGC audit jobs.
type Consumer struct {
	cfg     *config.Config
	service *audit.Service
}

// NewConsumer creates a consumer bound to the audit service.
func NewConsumer(cfg *config.Config, service *audit.Service) *Consumer {
	return &Consumer{cfg: cfg, service: service}
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
	if c == nil || c.service == nil {
		return fmt.Errorf("consumer not initialized")
	}
	var evt UGCAuditEvent
	if err := json.Unmarshal(payload, &evt); err != nil {
		return fmt.Errorf("decode event: %w", err)
	}
	switch evt.EventType {
	case eventUGCAuditRequested:
		_, err := c.service.EnqueueUGCAsync(ctx, audit.SyncRequest{
			TargetRef: evt.TargetRef,
			Region:    evt.Region,
			MediaType: evt.MediaType,
			ObjectKey: evt.ObjectKey,
		})
		return err
	case eventUGCAuditComplete:
		if evt.JobID == "" {
			return fmt.Errorf("jobId required for %s", evt.EventType)
		}
		_, err := c.service.CompleteUGCAsync(ctx, evt.JobID, audit.SyncRequest{
			TargetRef: evt.TargetRef,
			Region:    evt.Region,
			MediaType: evt.MediaType,
			ObjectKey: evt.ObjectKey,
		})
		return err
	default:
		return fmt.Errorf("unsupported event type %q", evt.EventType)
	}
}
