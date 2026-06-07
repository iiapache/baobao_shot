package inbox

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/baobao/notification-svc/internal/model"
	"github.com/baobao/notification-svc/internal/store"
)

func TestServiceListUnreadCount(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st)
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 8, 0, 0, 0, time.UTC)

	for i := 0; i < 55; i++ {
		if _, err := st.InsertNotification(ctx, store.InsertNotificationInput{
			ID: fmt.Sprintf("ntf_%03d", i), UserID: "usr_inbox", Category: model.CategoryMilestone,
			CreatedAt: now.Add(time.Duration(i) * time.Second),
		}); err != nil {
			t.Fatal(err)
		}
	}

	page1, err := svc.List(ctx, ListInput{UserID: "usr_inbox", Limit: 50})
	if err != nil {
		t.Fatal(err)
	}
	if len(page1.Items) != 50 {
		t.Fatalf("items = %d, want 50", len(page1.Items))
	}
	if page1.UnreadCount != 55 {
		t.Fatalf("unread = %d, want 55", page1.UnreadCount)
	}
	if page1.NextCursor == nil || *page1.NextCursor == "" {
		t.Fatal("expected next cursor")
	}

	page2, err := svc.List(ctx, ListInput{UserID: "usr_inbox", Cursor: *page1.NextCursor, Limit: 50})
	if err != nil {
		t.Fatal(err)
	}
	if len(page2.Items) != 5 {
		t.Fatalf("page2 items = %d", len(page2.Items))
	}
}

func TestServiceMarkReadUpdatesUnreadCount(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st)
	ctx := context.Background()

	n1, err := svc.Create(ctx, CreateInput{UserID: "usr_read", Category: model.CategoryAIDone})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Create(ctx, CreateInput{UserID: "usr_read", Category: model.CategoryCredit}); err != nil {
		t.Fatal(err)
	}

	result, err := svc.MarkRead(ctx, MarkReadInput{UserID: "usr_read", IDs: []string{n1.ID}})
	if err != nil {
		t.Fatal(err)
	}
	if result.MarkedCount != 1 || result.UnreadCount != 1 {
		t.Fatalf("result = %+v", result)
	}

	result, err = svc.MarkRead(ctx, MarkReadInput{UserID: "usr_read", All: true})
	if err != nil {
		t.Fatal(err)
	}
	if result.MarkedCount != 1 || result.UnreadCount != 0 {
		t.Fatalf("result all = %+v", result)
	}
}

func TestServiceSubscriptionsDefaultsAndPatch(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st)
	ctx := context.Background()

	got, err := svc.GetSubscriptions(ctx, "usr_sub")
	if err != nil {
		t.Fatal(err)
	}
	if len(got.Subscriptions) != len(model.AllCategories) {
		t.Fatalf("subs len = %d", len(got.Subscriptions))
	}
	for _, sub := range got.Subscriptions {
		if sub.Category == model.CategorySystem && sub.Enabled {
			t.Fatalf("SYSTEM default should be false: %+v", sub)
		}
		if sub.Category == model.CategoryAIDone && !sub.Enabled {
			t.Fatalf("AI_DONE default should be true: %+v", sub)
		}
	}

	updated, err := svc.UpdateSubscriptions(ctx, "usr_sub", []SubscriptionPatchItem{
		{Category: model.CategorySystem, Enabled: true},
		{Category: model.CategoryAIDone, Enabled: false},
	})
	if err != nil {
		t.Fatal(err)
	}
	byCategory := map[string]bool{}
	for _, sub := range updated.Subscriptions {
		byCategory[sub.Category] = sub.Enabled
	}
	if !byCategory[model.CategorySystem] || byCategory[model.CategoryAIDone] {
		t.Fatalf("patch result = %+v", byCategory)
	}
}

func TestServiceCreatePayload(t *testing.T) {
	svc := NewService(store.NewMemoryStore())
	n, err := svc.Create(context.Background(), CreateInput{
		UserID: "usr_create", Category: model.CategoryFamilyActivity,
		Payload: json.RawMessage(`{"postId":"post_1"}`),
	})
	if err != nil {
		t.Fatal(err)
	}
	if n.ID == "" || string(n.Payload) != `{"postId":"post_1"}` {
		t.Fatalf("notification = %+v", n)
	}
}
