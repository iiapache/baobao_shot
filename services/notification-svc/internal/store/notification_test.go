package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/baobao/notification-svc/internal/model"
)

func TestMemoryStoreNotificationLifecycle(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)

	for i := 0; i < 3; i++ {
		_, err := st.InsertNotification(ctx, InsertNotificationInput{
			ID:        "ntf_" + string(rune('a'+i)),
			UserID:    "usr_1",
			Category:  model.CategoryAIDone,
			Payload:   json.RawMessage(`{"taskId":"tsk_` + string(rune('a'+i)) + `"}`),
			CreatedAt: now.Add(time.Duration(i) * time.Minute),
		})
		if err != nil {
			t.Fatal(err)
		}
	}

	page1, err := st.ListNotifications(ctx, ListNotificationsInput{UserID: "usr_1", Limit: 2})
	if err != nil {
		t.Fatal(err)
	}
	if len(page1.Items) != 2 || page1.NextCursor == "" {
		t.Fatalf("page1 = %+v", page1)
	}

	page2, err := st.ListNotifications(ctx, ListNotificationsInput{
		UserID: "usr_1",
		Cursor: page1.NextCursor,
		Limit:  2,
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(page2.Items) != 1 || page2.NextCursor != "" {
		t.Fatalf("page2 = %+v", page2)
	}

	unread, err := st.CountUnreadNotifications(ctx, "usr_1")
	if err != nil || unread != 3 {
		t.Fatalf("unread = %d, err = %v", unread, err)
	}

	marked, err := st.MarkNotificationsRead(ctx, MarkNotificationsReadInput{
		UserID: "usr_1",
		IDs:    []string{"ntf_a"},
		ReadAt: now.Add(5 * time.Minute),
	})
	if err != nil || marked != 1 {
		t.Fatalf("marked = %d, err = %v", marked, err)
	}

	unread, err = st.CountUnreadNotifications(ctx, "usr_1")
	if err != nil || unread != 2 {
		t.Fatalf("unread after partial = %d", unread)
	}

	marked, err = st.MarkNotificationsRead(ctx, MarkNotificationsReadInput{
		UserID: "usr_1",
		All:    true,
		ReadAt: now.Add(6 * time.Minute),
	})
	if err != nil || marked != 2 {
		t.Fatalf("marked all = %d, err = %v", marked, err)
	}

	unread, err = st.CountUnreadNotifications(ctx, "usr_1")
	if err != nil || unread != 0 {
		t.Fatalf("unread after all = %d", unread)
	}
}

func TestMemoryStoreSubscriptions(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()

	rows, err := st.ListSubscriptionRows(ctx, "usr_sub")
	if err != nil || len(rows) != 0 {
		t.Fatalf("rows = %+v, err = %v", rows, err)
	}

	if err := st.UpsertSubscriptions(ctx, "usr_sub", []SubscriptionUpdate{
		{Category: model.CategorySystem, Enabled: true},
		{Category: model.CategoryAIDone, Enabled: false},
	}); err != nil {
		t.Fatal(err)
	}

	rows, err = st.ListSubscriptionRows(ctx, "usr_sub")
	if err != nil || len(rows) != 2 {
		t.Fatalf("rows = %+v, err = %v", rows, err)
	}
}

func TestNotificationCursorRoundTrip(t *testing.T) {
	n := model.Notification{
		ID:        "ntf_cursor",
		CreatedAt: time.Date(2026, 6, 6, 12, 0, 0, 123456789, time.UTC),
	}
	cursor := EncodeNotificationCursor(n)
	gotTime, gotID, err := ParseNotificationCursor(cursor)
	if err != nil {
		t.Fatal(err)
	}
	if gotID != n.ID || !gotTime.Equal(n.CreatedAt) {
		t.Fatalf("cursor decode = %v %s", gotTime, gotID)
	}
}

func TestPostgresStoreNotifications(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}

	ctx := context.Background()
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	if err := WaitForPostgres(ctx, db); err != nil {
		t.Fatal(err)
	}
	if err := applyEmbeddedMigrations(ctx, db, migrationDirectionUp); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = RollbackMigrations(context.Background(), db) })

	st := NewPostgresStore(db)
	now := time.Now().UTC()

	n, err := st.InsertNotification(ctx, InsertNotificationInput{
		ID: "ntf_pg", UserID: "usr_pg", Category: model.CategoryCredit,
		Payload: json.RawMessage(`{"amount":10}`), CreatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}
	if n.ID != "ntf_pg" {
		t.Fatalf("id = %s", n.ID)
	}

	unread, err := st.CountUnreadNotifications(ctx, "usr_pg")
	if err != nil || unread != 1 {
		t.Fatalf("unread = %d, err = %v", unread, err)
	}

	marked, err := st.MarkNotificationsRead(ctx, MarkNotificationsReadInput{
		UserID: "usr_pg", All: true, ReadAt: now,
	})
	if err != nil || marked != 1 {
		t.Fatalf("marked = %d, err = %v", marked, err)
	}

	if err := st.UpsertSubscriptions(ctx, "usr_pg", []SubscriptionUpdate{
		{Category: model.CategorySystem, Enabled: false},
	}); err != nil {
		t.Fatal(err)
	}
	subs, err := st.ListSubscriptionRows(ctx, "usr_pg")
	if err != nil || len(subs) != 1 || subs[0].Enabled {
		t.Fatalf("subs = %+v, err = %v", subs, err)
	}
}
