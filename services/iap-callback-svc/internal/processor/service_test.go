package processor

import (
	"context"
	"errors"
	"testing"

	"github.com/baobao/iap-callback-svc/internal/idempotency"
	"github.com/baobao/iap-callback-svc/internal/kafka"
)

func TestHandleRefundPublishesKafkaEvent(t *testing.T) {
	producer := kafka.NewStubProducer()
	svc := NewService(idempotency.NewMemoryStore(), producer, kafka.TopicIAPEvents)

	payload := "mock-asn:REFUND:notif-refund-1:mock:2000000123456789:credit_pack_60"
	result, err := svc.Handle(context.Background(), payload)
	if err != nil {
		t.Fatalf("Handle() error = %v", err)
	}
	if result.EventType != kafka.EventIAPRefund {
		t.Fatalf("EventType = %q, want %q", result.EventType, kafka.EventIAPRefund)
	}
	if !result.Published {
		t.Fatal("expected event published")
	}

	msgs := producer.Messages(kafka.TopicIAPEvents)
	if len(msgs) != 1 {
		t.Fatalf("messages = %d, want 1", len(msgs))
	}
	if msgs[0].TransactionID != "2000000123456789" || msgs[0].ProductID != "credit_pack_60" {
		t.Fatalf("event = %+v", msgs[0])
	}
}

func TestHandleDuplicateNotification(t *testing.T) {
	producer := kafka.NewStubProducer()
	store := idempotency.NewMemoryStore()
	svc := NewService(store, producer, kafka.TopicIAPEvents)
	payload := "mock-asn:REFUND:notif-dup:mock:tx_dup:credit_pack_60"

	if _, err := svc.Handle(context.Background(), payload); err != nil {
		t.Fatalf("first Handle() error = %v", err)
	}
	_, err := svc.Handle(context.Background(), payload)
	if !errors.Is(err, ErrDuplicate) {
		t.Fatalf("second Handle() error = %v, want ErrDuplicate", err)
	}
	if len(producer.Messages(kafka.TopicIAPEvents)) != 1 {
		t.Fatal("duplicate should not publish another event")
	}
}

func TestHandleRevokePublishesEvent(t *testing.T) {
	producer := kafka.NewStubProducer()
	svc := NewService(idempotency.NewMemoryStore(), producer, kafka.TopicIAPEvents)

	payload := "mock-asn:REVOKE:notif-revoke-1:mock:2000000999999999:com.baobao.sub.monthly:orig_sub_1"
	result, err := svc.Handle(context.Background(), payload)
	if err != nil {
		t.Fatalf("Handle() error = %v", err)
	}
	if result.EventType != kafka.EventIAPRevoke {
		t.Fatalf("EventType = %q, want %q", result.EventType, kafka.EventIAPRevoke)
	}
}
