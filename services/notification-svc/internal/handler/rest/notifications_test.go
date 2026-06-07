package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/notification-svc/internal/config"
	"github.com/baobao/notification-svc/internal/model"
	"github.com/baobao/notification-svc/internal/store"
)

func seedNotifications(t *testing.T, st *store.MemoryStore, userID string, count int) {
	t.Helper()
	ctx := t.Context()
	now := time.Date(2026, 6, 6, 9, 0, 0, 0, time.UTC)
	for i := 0; i < count; i++ {
		if _, err := st.InsertNotification(ctx, store.InsertNotificationInput{
			ID: "ntf_" + string(rune('a'+i)), UserID: userID, Category: model.CategoryMilestone,
			CreatedAt: now.Add(time.Duration(i) * time.Minute),
		}); err != nil {
			t.Fatal(err)
		}
	}
}

func TestListNotificationsPaginationAndUnread(t *testing.T) {
	st := store.NewMemoryStore()
	seedNotifications(t, st, "usr_list", 3)
	handler := NewRouter(testConfig(), st, nil)

	req := httptest.NewRequest(http.MethodGet, "/v1/notifications?limit=2", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_list")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rr.Code, rr.Body.String())
	}

	var resp apiResponse
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatalf("data type = %T", resp.Data)
	}
	items := data["items"].([]any)
	if len(items) != 2 {
		t.Fatalf("items len = %d", len(items))
	}
	if data["unreadCount"].(float64) != 3 {
		t.Fatalf("unreadCount = %v", data["unreadCount"])
	}
	if data["nextCursor"] == nil {
		t.Fatal("expected nextCursor")
	}
}

func TestMarkReadBatchAndAll(t *testing.T) {
	st := store.NewMemoryStore()
	seedNotifications(t, st, "usr_mark", 2)
	handler := NewRouter(testConfig(), st, nil)

	body, _ := json.Marshal(map[string]any{"ids": []string{"ntf_a"}})
	req := httptest.NewRequest(http.MethodPost, "/v1/notifications/mark-read", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:usr_mark")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("batch status = %d, body = %s", rr.Code, rr.Body.String())
	}

	var resp apiResponse
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	if data["markedCount"].(float64) != 1 || data["unreadCount"].(float64) != 1 {
		t.Fatalf("batch data = %+v", data)
	}

	req2 := httptest.NewRequest(http.MethodPost, "/v1/notifications/mark-read", bytes.NewReader([]byte(`{"all":true}`)))
	req2.Header.Set("Authorization", "Bearer dev:usr_mark")
	rr2 := httptest.NewRecorder()
	handler.ServeHTTP(rr2, req2)
	if rr2.Code != http.StatusOK {
		t.Fatalf("all status = %d", rr2.Code)
	}
	if err := json.NewDecoder(rr2.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	data2 := resp.Data.(map[string]any)
	if data2["unreadCount"].(float64) != 0 {
		t.Fatalf("unread after all = %v", data2["unreadCount"])
	}
}

func TestGetSubscriptionsDefaults(t *testing.T) {
	handler := NewRouter(testConfig(), store.NewMemoryStore(), nil)
	req := httptest.NewRequest(http.MethodGet, "/v1/notifications/subscriptions", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_sub_default")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rr.Code, rr.Body.String())
	}

	var resp apiResponse
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	subs := data["subscriptions"].([]any)
	if len(subs) != len(model.AllCategories) {
		t.Fatalf("subs len = %d", len(subs))
	}
}

func TestPatchSubscriptions(t *testing.T) {
	handler := NewRouter(testConfig(), store.NewMemoryStore(), nil)
	body, _ := json.Marshal(map[string]any{
		"subscriptions": []map[string]any{
			{"category": model.CategorySystem, "enabled": true},
			{"category": model.CategoryAIDone, "enabled": false},
		},
	})
	req := httptest.NewRequest(http.MethodPatch, "/v1/notifications/subscriptions", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:usr_sub_patch")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rr.Code, rr.Body.String())
	}
}

func TestListNotificationsUnauthorized(t *testing.T) {
	handler := newTestRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/v1/notifications", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d", rr.Code)
	}
}

func TestListNotificationsInvalidCursor(t *testing.T) {
	handler := newTestRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/v1/notifications?cursor=bad", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_bad_cursor")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("status = %d", rr.Code)
	}
}

func testConfig() *config.Config {
	return &config.Config{ServiceName: "notification-svc", DebugEndpoints: false}
}