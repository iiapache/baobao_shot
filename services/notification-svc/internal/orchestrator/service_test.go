package orchestrator

import (
	"context"
	"encoding/json"
	"sync"
	"testing"

	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/inbox"
	"github.com/baobao/notification-svc/internal/model"
	"github.com/baobao/notification-svc/internal/store"
)

type recordingSender struct {
	mu       sync.Mutex
	payloads []apns.PushPayload
}

func (r *recordingSender) Send(_ context.Context, _ string, payload apns.PushPayload) (apns.SendResult, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.payloads = append(r.payloads, payload)
	return apns.SendResult{APNSID: "rec_1", StatusCode: 200}, nil
}

func (r *recordingSender) all() []apns.PushPayload {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]apns.PushPayload, len(r.payloads))
	copy(out, r.payloads)
	return out
}

func TestPushPriority(t *testing.T) {
	if PushPriority(model.CategoryAIDone) != 10 {
		t.Fatal("AI_DONE should be high priority")
	}
	if PushPriority(model.CategoryMilestone) != 5 {
		t.Fatal("MILESTONE should be normal priority")
	}
}

func TestDispatchCreatesInboxAndPushes(t *testing.T) {
	st := store.NewMemoryStore()
	ctx := context.Background()
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	if _, err := st.UpsertDeviceToken(ctx, store.UpsertDeviceTokenInput{
		UserID: "usr_1", DeviceID: "dev_1", APNSToken: token, Region: "cn",
	}); err != nil {
		t.Fatal(err)
	}

	rec := &recordingSender{}
	apnsClient, err := apns.NewClient(apns.Config{Sender: rec})
	if err != nil {
		t.Fatal(err)
	}

	svc := NewService(st, inbox.NewService(st), apnsClient, "app.babycamera")
	payload, _ := json.Marshal(map[string]string{"taskId": "tsk_1"})
	result, err := svc.Dispatch(ctx, DispatchInput{
		UserID:   "usr_1",
		Category: model.CategoryAIDone,
		Title:    "AI 任务完成",
		Body:     "作品已生成",
		Payload:  payload,
		CustomData: map[string]string{
			"taskId": "tsk_1",
			"state":  "succeeded",
		},
		SilentPush: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if !result.InboxCreated {
		t.Fatal("expected inbox entry")
	}
	if result.PushAttempts != 2 {
		t.Fatalf("push attempts = %d, want 2 (silent + alert)", result.PushAttempts)
	}

	sends := rec.all()
	if len(sends) != 2 {
		t.Fatalf("sends = %d", len(sends))
	}
	if !sends[0].Silent {
		t.Fatal("first push should be silent")
	}
	if sends[0].CustomData["taskId"] != "tsk_1" {
		t.Fatalf("custom data = %#v", sends[0].CustomData)
	}
	if sends[1].Silent {
		t.Fatal("second push should be alert")
	}
	if sends[1].Title != "AI 任务完成" {
		t.Fatalf("alert title = %q", sends[1].Title)
	}

	unread, err := st.CountUnreadNotifications(ctx, "usr_1")
	if err != nil {
		t.Fatal(err)
	}
	if unread != 1 {
		t.Fatalf("unread = %d", unread)
	}
}

func TestDispatchSkipsPushWhenCategoryDisabled(t *testing.T) {
	st := store.NewMemoryStore()
	ctx := context.Background()
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	if _, err := st.UpsertDeviceToken(ctx, store.UpsertDeviceTokenInput{
		UserID: "usr_2", DeviceID: "dev_1", APNSToken: token, Region: "cn",
	}); err != nil {
		t.Fatal(err)
	}
	if err := st.UpsertSubscriptions(ctx, "usr_2", []store.SubscriptionUpdate{
		{Category: model.CategorySystem, Enabled: false},
	}); err != nil {
		t.Fatal(err)
	}

	rec := &recordingSender{}
	apnsClient, err := apns.NewClient(apns.Config{Sender: rec})
	if err != nil {
		t.Fatal(err)
	}
	svc := NewService(st, inbox.NewService(st), apnsClient, "app.babycamera")

	result, err := svc.Dispatch(ctx, DispatchInput{
		UserID:   "usr_2",
		Category: model.CategorySystem,
		Title:    "活动通知",
		Body:     "限时活动",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !result.InboxCreated {
		t.Fatal("expected inbox entry even when push disabled")
	}
	if result.PushAttempts != 0 {
		t.Fatalf("push attempts = %d, want 0", result.PushAttempts)
	}
	if len(rec.all()) != 0 {
		t.Fatal("expected no APNs sends")
	}
}

func TestDispatchFamilyActivityHighPriority(t *testing.T) {
	st := store.NewMemoryStore()
	ctx := context.Background()
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	if _, err := st.UpsertDeviceToken(ctx, store.UpsertDeviceTokenInput{
		UserID: "usr_3", DeviceID: "dev_1", APNSToken: token, Region: "os",
	}); err != nil {
		t.Fatal(err)
	}

	rec := &recordingSender{}
	apnsClient, err := apns.NewClient(apns.Config{Sender: rec})
	if err != nil {
		t.Fatal(err)
	}
	svc := NewService(st, inbox.NewService(st), apnsClient, "app.babycamera")

	_, err = svc.Dispatch(ctx, DispatchInput{
		UserID:   "usr_3",
		Category: model.CategoryFamilyActivity,
		Title:    "家庭圈有新动态",
		Body:     "妈妈 发布了新作品",
	})
	if err != nil {
		t.Fatal(err)
	}

	sends := rec.all()
	if len(sends) != 1 {
		t.Fatalf("sends = %d", len(sends))
	}
	if sends[0].Priority != 10 {
		t.Fatalf("priority = %d, want 10", sends[0].Priority)
	}
}
