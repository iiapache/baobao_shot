package kafka

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/baobao/audit-svc/internal/audit"
	"github.com/baobao/audit-svc/internal/config"
	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
)

func TestHandleMessageUGCAsync(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := audit.NewService(mem, nil)
	consumer := NewConsumer(&config.Config{}, svc)
	ctx := context.Background()

	enqueuePayload, err := json.Marshal(UGCAuditEvent{
		EventType: eventUGCAuditRequested,
		TargetRef: "post_item_2",
		Region:    "cn",
		MediaType: "image",
		ObjectKey: "family/fam_1/pending/item2.jpg",
	})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if err := consumer.HandleMessage(ctx, enqueuePayload); err != nil {
		t.Fatalf("enqueue event: %v", err)
	}

	pending, err := svc.EnqueueUGCAsync(ctx, audit.SyncRequest{
		TargetRef: "post_item_3",
		Region:    "cn",
		MediaType: "image",
		ObjectKey: "family/fam_1/pending/item3.jpg",
	})
	if err != nil {
		t.Fatalf("enqueue direct: %v", err)
	}

	completePayload, err := json.Marshal(UGCAuditEvent{
		EventType: eventUGCAuditComplete,
		JobID:     pending.ID,
		TargetRef: pending.TargetRef,
		Region:    pending.Region,
		MediaType: "image",
		ObjectKey: "family/fam_1/pending/item3.jpg",
	})
	if err != nil {
		t.Fatalf("marshal complete: %v", err)
	}
	if err := consumer.HandleMessage(ctx, completePayload); err != nil {
		t.Fatalf("complete event: %v", err)
	}

	job, err := svc.GetAuditJob(ctx, pending.ID)
	if err != nil {
		t.Fatalf("get job: %v", err)
	}
	if job.Status != model.AuditStatusPassed {
		t.Fatalf("status = %s, want passed", job.Status)
	}
}

func TestConsumerStartDisabled(t *testing.T) {
	consumer := NewConsumer(&config.Config{}, audit.NewService(store.NewMemoryStore(), nil))
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := consumer.Start(ctx); err != nil {
		t.Fatalf("Start: %v", err)
	}
}
