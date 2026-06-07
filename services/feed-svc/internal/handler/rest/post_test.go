package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/feed-svc/internal/config"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/store"
)

func newTestRouter(t *testing.T) http.Handler {
	t.Helper()
	cfg := &config.Config{ServiceName: "feed-svc-test"}
	return NewRouter(cfg, store.NewMemoryStore(), RouterDeps{})
}

func authRequest(method, target string, body []byte, userID string) *http.Request {
	req := httptest.NewRequest(method, target, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:"+userID)
	req.Header.Set("X-Region", "cn")
	req.Header.Set("Content-Type", "application/json")
	return req
}

func postCreateBody(caption string, withMedia bool) []byte {
	payload := map[string]any{
		"familyId":   "fam_test",
		"babyIds":    []string{"bb_test"},
		"caption":    caption,
		"visibility": model.VisibilityFamily,
	}
	if withMedia {
		payload["items"] = []map[string]any{{
			"kind":      model.ItemKindImage,
			"objectKey": "family/fam_test/post/1.heic",
			"width":     1024,
			"height":    1024,
		}}
	}
	body, _ := json.Marshal(payload)
	return body
}

func TestPostCreateUnauthorized(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/posts", bytes.NewReader(postCreateBody("ok", false)))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestPostCreateHappyPublished(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/posts", postCreateBody("hello feed", false), "usr_happy"))
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
	if out["status"] != model.PostStatusPublished {
		t.Fatalf("status = %v", out["status"])
	}
}

func TestPostCreateWithMediaAuditStatus(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/posts", postCreateBody("with media", true), "usr_media"))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var out map[string]any
	_ = json.Unmarshal(data, &out)
	if out["status"] != model.PostStatusAudit {
		t.Fatalf("status = %v, want audit", out["status"])
	}
}

func TestPostCreateTextRejectedHTTP(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/posts", postCreateBody("reject_spam 广告", false), "usr_reject"))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil || resp.Code != "POST_AUDIT_REJECTED" {
		t.Fatalf("response = %+v err = %v", resp, err)
	}
}

func TestPostCreateRateLimitHTTP(t *testing.T) {
	router := newTestRouter(t)
	userID := "usr_rate"

	for i := 0; i < 5; i++ {
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/posts", postCreateBody("ok", false), userID))
		if rec.Code != http.StatusOK {
			t.Fatalf("request #%d status = %d", i+1, rec.Code)
		}
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/posts", postCreateBody("ok", false), userID))
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("6th status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil || resp.Code != "COMMON_RATE_LIMIT" {
		t.Fatalf("response = %+v err = %v", resp, err)
	}
}

func TestPostDeleteHappy(t *testing.T) {
	router := newTestRouter(t)
	createRec := httptest.NewRecorder()
	router.ServeHTTP(createRec, authRequest(http.MethodPost, "/v1/posts", postCreateBody("delete me", true), "usr_delete"))
	if createRec.Code != http.StatusOK {
		t.Fatalf("create status = %d body = %s", createRec.Code, createRec.Body.String())
	}
	createResp, err := decodeAPIResponse(createRec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(createResp.Data)
	var created map[string]any
	if err := json.Unmarshal(data, &created); err != nil {
		t.Fatal(err)
	}
	postID, _ := created["postId"].(string)
	if postID == "" {
		t.Fatal("missing postId")
	}

	delRec := httptest.NewRecorder()
	router.ServeHTTP(delRec, authRequest(http.MethodDelete, "/v1/posts/"+postID, nil, "usr_delete"))
	if delRec.Code != http.StatusOK {
		t.Fatalf("delete status = %d body = %s", delRec.Code, delRec.Body.String())
	}
	delResp, err := decodeAPIResponse(delRec.Body.Bytes())
	if err != nil || delResp.Code != "OK" {
		t.Fatalf("response = %+v err = %v", delResp, err)
	}
}

func TestPostDeleteForbidden(t *testing.T) {
	router := newTestRouter(t)
	createRec := httptest.NewRecorder()
	router.ServeHTTP(createRec, authRequest(http.MethodPost, "/v1/posts", postCreateBody("owner only", false), "usr_owner"))
	if createRec.Code != http.StatusOK {
		t.Fatalf("create status = %d", createRec.Code)
	}
	createResp, _ := decodeAPIResponse(createRec.Body.Bytes())
	data, _ := json.Marshal(createResp.Data)
	var created map[string]any
	_ = json.Unmarshal(data, &created)
	postID, _ := created["postId"].(string)

	delRec := httptest.NewRecorder()
	router.ServeHTTP(delRec, authRequest(http.MethodDelete, "/v1/posts/"+postID, nil, "usr_other"))
	if delRec.Code != http.StatusForbidden {
		t.Fatalf("status = %d body = %s", delRec.Code, delRec.Body.String())
	}
}

func TestPostDeleteNotFound(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/posts/pst_missing", nil, "usr_delete"))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
}
