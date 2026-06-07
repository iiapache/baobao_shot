package rest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/feed-svc/internal/config"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/store"
)

func seedFeedHTTPPosts(t *testing.T, st store.Store) {
	t.Helper()
	ctx := t.Context()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	for i, id := range []string{"post_http_2", "post_http_1"} {
		if _, err := st.CreatePost(ctx, store.CreatePostInput{
			ID: id, FamilyID: "fam_http", OwnerUserID: "usr_http", Status: model.PostStatusPublished,
			Visibility: model.VisibilityFamily, Caption: id, CreatedAt: now.Add(time.Duration(i) * time.Minute),
		}); err != nil {
			t.Fatal(err)
		}
	}
}

func feedAuthRequest(target, userID, familiesJSON string) *http.Request {
	req := httptest.NewRequest(http.MethodGet, target, nil)
	req.Header.Set("Authorization", "Bearer dev:"+userID)
	req.Header.Set("X-Region", "cn")
	if familiesJSON != "" {
		req.Header.Set("X-Families", familiesJSON)
	}
	return req
}

func TestFeedListFamilyUnauthorized(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/feeds/family?familyId=fam_test", nil)
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d", rec.Code)
	}
}

func TestFeedListFamilyHappyPath(t *testing.T) {
	st := store.NewMemoryStore()
	seedFeedHTTPPosts(t, st)
	cfg := &config.Config{ServiceName: "feed-svc-test"}
	router := NewRouter(cfg, st, RouterDeps{})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, feedAuthRequest(
		"/v1/feeds/family?familyId=fam_http&limit=20",
		"usr_http",
		`[{"familyId":"fam_http","role":"family"}]`,
	))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil || resp.Code != "OK" {
		t.Fatalf("response = %+v err = %v", resp, err)
	}
	data, _ := json.Marshal(resp.Data)
	var out map[string]any
	if err := json.Unmarshal(data, &out); err != nil {
		t.Fatal(err)
	}
	items, _ := out["items"].([]any)
	if len(items) != 2 {
		t.Fatalf("items = %d", len(items))
	}
	if out["cacheTtlSeconds"].(float64) != 60 {
		t.Fatalf("cacheTtlSeconds = %v", out["cacheTtlSeconds"])
	}
}

func TestFeedListFamilyForbidden(t *testing.T) {
	st := store.NewMemoryStore()
	seedFeedHTTPPosts(t, st)
	cfg := &config.Config{ServiceName: "feed-svc-test"}
	router := NewRouter(cfg, st, RouterDeps{})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, feedAuthRequest(
		"/v1/feeds/family?familyId=fam_http",
		"usr_other",
		`[{"familyId":"fam_other","role":"family"}]`,
	))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
}

func TestFeedListFamilyPaginationHTTP(t *testing.T) {
	st := store.NewMemoryStore()
	seedFeedHTTPPosts(t, st)
	cfg := &config.Config{ServiceName: "feed-svc-test"}
	router := NewRouter(cfg, st, RouterDeps{})
	families := `[{"familyId":"fam_http","role":"guest"}]`

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, feedAuthRequest("/v1/feeds/family?familyId=fam_http&limit=1", "usr_http", families))
	if rec.Code != http.StatusOK {
		t.Fatalf("page1 status = %d", rec.Code)
	}
	resp1, _ := decodeAPIResponse(rec.Body.Bytes())
	data1, _ := json.Marshal(resp1.Data)
	var page1 map[string]any
	_ = json.Unmarshal(data1, &page1)
	nextCursor, ok := page1["nextCursor"].(string)
	if !ok || nextCursor == "" {
		t.Fatalf("nextCursor = %#v", page1["nextCursor"])
	}

	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, feedAuthRequest("/v1/feeds/family?familyId=fam_http&limit=1&cursor="+nextCursor, "usr_http", families))
	if rec2.Code != http.StatusOK {
		t.Fatalf("page2 status = %d", rec2.Code)
	}
}
