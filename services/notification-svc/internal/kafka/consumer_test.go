package kafka

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/config"
	"github.com/baobao/notification-svc/internal/inbox"
	"github.com/baobao/notification-svc/internal/model"
	"github.com/baobao/notification-svc/internal/orchestrator"
	"github.com/baobao/notification-svc/internal/store"
)

func newTestConsumer(t *testing.T) (*Consumer, *store.MemoryStore, *apns.MockSender) {
	t.Helper()
	st := store.NewMemoryStore()
	mock := apns.NewMockSender()
	apnsClient, err := apns.NewClient(apns.Config{Sender: mock})
	if err != nil {
		t.Fatal(err)
	}
	orch := orchestrator.NewService(st, inbox.NewService(st), apnsClient, "app.babycamera")
	return NewConsumer(&config.Config{}, orch), st, mock
}

func TestHandleMessageAITaskSucceededSilentAndAlert(t *testing.T) {
	consumer, st, mock := newTestConsumer(t)
	ctx := context.Background()
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	if _, err := st.UpsertDeviceToken(ctx, store.UpsertDeviceTokenInput{
		UserID: "usr_ai", DeviceID: "dev_1", APNSToken: token, Region: "cn",
	}); err != nil {
		t.Fatal(err)
	}

	payload, err := json.Marshal(AIEvent{
		EventType:    EventAITaskSucceeded,
		UserID:       "usr_ai",
		TaskID:       "tsk_42",
		State:        "succeeded",
		ResultURL:    "https://cdn.example/ai-out/tsk_42.jpg",
		ThumbnailURL: "https://cdn.example/ai-out/tsk_42_thumb.jpg",
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := consumer.HandleMessage(ctx, TopicAIEvents, payload); err != nil {
		t.Fatal(err)
	}
	if mock.SendCount() != 2 {
		t.Fatalf("send count = %d, want silent + alert", mock.SendCount())
	}

	items, err := st.ListNotifications(ctx, store.ListNotificationsInput{UserID: "usr_ai", Limit: 10})
	if err != nil {
		t.Fatal(err)
	}
	if len(items.Items) != 1 {
		t.Fatalf("notifications = %d", len(items.Items))
	}
	if items.Items[0].Category != model.CategoryAIDone {
		t.Fatalf("category = %q", items.Items[0].Category)
	}
}

func TestHandleMessageFeedMilestone(t *testing.T) {
	consumer, st, mock := newTestConsumer(t)
	ctx := context.Background()
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	if _, err := st.UpsertDeviceToken(ctx, store.UpsertDeviceTokenInput{
		UserID: "usr_ms", DeviceID: "dev_1", APNSToken: token, Region: "cn",
	}); err != nil {
		t.Fatal(err)
	}

	payload, _ := json.Marshal(FeedEvent{
		EventType:   EventFeedMilestoneReminder,
		UserID:      "usr_ms",
		BabyID:      "baby_1",
		MilestoneID: "ms_100d",
		Title:       "百天纪念",
		Body:        "宝宝满 100 天啦",
	})
	if err := consumer.HandleMessage(ctx, TopicFeedEvents, payload); err != nil {
		t.Fatal(err)
	}
	if mock.SendCount() != 1 {
		t.Fatalf("send count = %d", mock.SendCount())
	}
}

func TestHandleMessageCreditGranted(t *testing.T) {
	consumer, st, mock := newTestConsumer(t)
	ctx := context.Background()
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	if _, err := st.UpsertDeviceToken(ctx, store.UpsertDeviceTokenInput{
		UserID: "usr_cr", DeviceID: "dev_1", APNSToken: token, Region: "cn",
	}); err != nil {
		t.Fatal(err)
	}

	payload, _ := json.Marshal(CreditEvent{
		EventType:    EventCreditGranted,
		UserID:       "usr_cr",
		Amount:       20,
		BalanceAfter: 120,
		Reason:       "每日签到",
	})
	if err := consumer.HandleMessage(ctx, TopicCreditEvents, payload); err != nil {
		t.Fatal(err)
	}
	if mock.SendCount() != 1 {
		t.Fatalf("send count = %d", mock.SendCount())
	}
}

func TestHandleMessageFamilyActivityRespectsSubscription(t *testing.T) {
	consumer, st, mock := newTestConsumer(t)
	ctx := context.Background()
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	if _, err := st.UpsertDeviceToken(ctx, store.UpsertDeviceTokenInput{
		UserID: "usr_ff", DeviceID: "dev_1", APNSToken: token, Region: "cn",
	}); err != nil {
		t.Fatal(err)
	}
	if err := st.UpsertSubscriptions(ctx, "usr_ff", []store.SubscriptionUpdate{
		{Category: model.CategoryFamilyActivity, Enabled: false},
	}); err != nil {
		t.Fatal(err)
	}

	payload, _ := json.Marshal(FeedEvent{
		EventType: EventFeedPostLiked,
		UserID:    "usr_ff",
		ActorName: "爸爸",
		PostID:    "post_1",
	})
	if err := consumer.HandleMessage(ctx, TopicFeedEvents, payload); err != nil {
		t.Fatal(err)
	}
	if mock.SendCount() != 0 {
		t.Fatalf("send count = %d, want 0 when unsubscribed", mock.SendCount())
	}
	unread, err := st.CountUnreadNotifications(ctx, "usr_ff")
	if err != nil {
		t.Fatal(err)
	}
	if unread != 1 {
		t.Fatalf("unread = %d, inbox should still record", unread)
	}
}

func TestHandleMessageUnsupportedEvent(t *testing.T) {
	consumer, _, _ := newTestConsumer(t)
	payload, _ := json.Marshal(map[string]string{
		"eventType": "unknown.event",
		"userId":    "usr_x",
	})
	err := consumer.HandleMessage(context.Background(), TopicAIEvents, payload)
	if err == nil {
		t.Fatal("expected error for unsupported event")
	}
}

func TestConsumerStartDisabled(t *testing.T) {
	consumer := NewConsumer(&config.Config{}, orchestrator.NewService(store.NewMemoryStore(), inbox.NewService(store.NewMemoryStore()), nil, ""))
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := consumer.Start(ctx); err != nil {
		t.Fatal(err)
	}
}
