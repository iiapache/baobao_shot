package rest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/feed-svc/internal/config"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/store"
)

func seedEngagementPost(t *testing.T, st store.Store, postID string) {
	t.Helper()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	if _, err := st.CreatePost(ctx, store.CreatePostInput{
		ID: postID, FamilyID: "fam_eng", OwnerUserID: "usr_owner",
		Status: model.PostStatusPublished, Visibility: model.VisibilityFamily, CreatedAt: now,
	}); err != nil {
		t.Fatal(err)
	}
}

func engagementAuthRequest(method, target string, body []byte, userID string) *http.Request {
	req := authRequest(method, target, body, userID)
	req.Header.Set("X-Families", `[{"familyId":"fam_eng","role":"family"}]`)
	return req
}

func TestEngagementLikeHTTP(t *testing.T) {
	st := store.NewMemoryStore()
	seedEngagementPost(t, st, "post_like_http")
	router := NewRouter(&config.Config{ServiceName: "feed-svc-test"}, st, RouterDeps{})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, engagementAuthRequest(http.MethodPost, "/v1/posts/post_like_http/likes", nil, "usr_like"))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}

	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, engagementAuthRequest(http.MethodPost, "/v1/posts/post_like_http/likes", nil, "usr_like"))
	if rec2.Code != http.StatusOK {
		t.Fatalf("duplicate status = %d", rec2.Code)
	}
	resp, _ := decodeAPIResponse(rec2.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var out map[string]any
	_ = json.Unmarshal(data, &out)
	if out["duplicate"] != true {
		t.Fatalf("duplicate = %v", out["duplicate"])
	}
}

func TestEngagementCommentAndDeleteHTTP(t *testing.T) {
	st := store.NewMemoryStore()
	seedEngagementPost(t, st, "post_cmt_http")
	router := NewRouter(&config.Config{ServiceName: "feed-svc-test"}, st, RouterDeps{})

	body, _ := json.Marshal(map[string]string{"text": "真好看"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, engagementAuthRequest(http.MethodPost, "/v1/posts/post_cmt_http/comments", body, "usr_cmt"))
	if rec.Code != http.StatusOK {
		t.Fatalf("create status = %d body = %s", rec.Code, rec.Body.String())
	}

	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var created map[string]any
	_ = json.Unmarshal(data, &created)
	commentID, _ := created["commentId"].(string)
	if commentID == "" {
		t.Fatalf("commentId missing: %+v", created)
	}

	recDel := httptest.NewRecorder()
	router.ServeHTTP(recDel, engagementAuthRequest(
		http.MethodDelete,
		"/v1/posts/post_cmt_http/comments/"+commentID,
		nil,
		"usr_cmt",
	))
	if recDel.Code != http.StatusOK {
		t.Fatalf("delete status = %d body = %s", recDel.Code, recDel.Body.String())
	}
}

func TestEngagementCommentAuditRejectedHTTP(t *testing.T) {
	st := store.NewMemoryStore()
	seedEngagementPost(t, st, "post_reject_http")
	router := NewRouter(&config.Config{ServiceName: "feed-svc-test"}, st, RouterDeps{})

	body, _ := json.Marshal(map[string]string{"text": "reject_spam 广告"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, engagementAuthRequest(http.MethodPost, "/v1/posts/post_reject_http/comments", body, "usr_cmt"))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
}

func TestEngagementUnlikeHTTP(t *testing.T) {
	st := store.NewMemoryStore()
	seedEngagementPost(t, st, "post_unlike_http")
	router := NewRouter(&config.Config{ServiceName: "feed-svc-test"}, st, RouterDeps{})

	recLike := httptest.NewRecorder()
	router.ServeHTTP(recLike, engagementAuthRequest(http.MethodPost, "/v1/posts/post_unlike_http/likes", nil, "usr_like"))
	if recLike.Code != http.StatusOK {
		t.Fatalf("like status = %d", recLike.Code)
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, engagementAuthRequest(http.MethodDelete, "/v1/posts/post_unlike_http/likes", nil, "usr_like"))
	if rec.Code != http.StatusOK {
		t.Fatalf("unlike status = %d body = %s", rec.Code, rec.Body.String())
	}

	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, engagementAuthRequest(http.MethodDelete, "/v1/posts/post_unlike_http/likes", nil, "usr_like"))
	if rec2.Code != http.StatusOK {
		t.Fatalf("second unlike status = %d", rec2.Code)
	}
}

func TestEngagementLikeNotFoundHTTP(t *testing.T) {
	st := store.NewMemoryStore()
	router := NewRouter(&config.Config{ServiceName: "feed-svc-test"}, st, RouterDeps{})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, engagementAuthRequest(http.MethodPost, "/v1/posts/missing/likes", nil, "usr_like"))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
}

func TestEngagementCommentEmptyTextHTTP(t *testing.T) {
	st := store.NewMemoryStore()
	seedEngagementPost(t, st, "post_empty")
	router := NewRouter(&config.Config{ServiceName: "feed-svc-test"}, st, RouterDeps{})

	body, _ := json.Marshal(map[string]string{"text": ""})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, engagementAuthRequest(
		http.MethodPost,
		"/v1/posts/post_empty/comments",
		body,
		"usr_cmt",
	))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
}
