package rest

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/media-svc/internal/config"
	"github.com/baobao/media-svc/internal/model"
	"github.com/baobao/media-svc/internal/store"
)

func newTestRouter(t *testing.T) (http.Handler, *store.MemoryUploadStore) {
	t.Helper()
	cfg := &config.Config{
		ServiceName:      "media-svc-test",
		JWTSigningSecret: "dev-only-change-me",
		STSTTLSeconds:    600,
		MockOSSBaseURL:   "http://localhost:18080/mock-oss",
	}
	mem := store.NewMemoryUploadStore()
	return NewRouter(cfg, mem), mem
}

func authRequest(method, target string, body []byte, userID string) *http.Request {
	req := httptest.NewRequest(method, target, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:"+userID)
	req.Header.Set("X-Region", "cn")
	req.Header.Set("Content-Type", "application/json")
	return req
}

func TestUploadInitUnauthorized(t *testing.T) {
	router, _ := newTestRouter(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/uploads/init", bytes.NewReader([]byte(`{"purpose":"ai-input","items":[]}`)))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestUploadInitAndCompletePostItem(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_smoke"

	initBody, _ := json.Marshal(map[string]any{
		"purpose":  "post-item",
		"familyId": "fam_smoke_001",
		"items": []map[string]any{{
			"clientRef": "photo-ref-001",
			"kind":      "photo",
			"mime":      "image/jpeg",
			"size":      1024,
			"sha256":    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		}},
	})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/uploads/init", initBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("init status = %d body = %s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil || resp.Code != "OK" {
		t.Fatalf("init response = %+v err = %v", resp, err)
	}
	if resp.RequestID == "" {
		t.Fatal("expected requestId")
	}

	data, _ := json.Marshal(resp.Data)
	var initData map[string]any
	if err := json.Unmarshal(data, &initData); err != nil {
		t.Fatal(err)
	}
	uploadID, _ := initData["uploadId"].(string)
	if uploadID == "" {
		t.Fatal("expected uploadId")
	}
	sts, _ := initData["sts"].(map[string]any)
	if sts["accessKeyId"] == nil || sts["securityToken"] == nil {
		t.Fatal("expected STS credentials")
	}
	items, _ := initData["items"].([]any)
	if len(items) != 1 {
		t.Fatalf("items len = %d", len(items))
	}
	first, _ := items[0].(map[string]any)
	if first["objectKey"] == nil || first["uploadUrl"] == nil {
		t.Fatal("expected objectKey and uploadUrl")
	}
	if int(first["expiresIn"].(float64)) != 600 {
		t.Fatalf("expiresIn = %v, want 600", first["expiresIn"])
	}

	session, err := mem.GetSession(context.Background(), uploadID)
	if err != nil {
		t.Fatalf("session not persisted: %v", err)
	}
	if session.Status != model.UploadStatusPending {
		t.Fatalf("session status = %q", session.Status)
	}

	completeBody, _ := json.Marshal(map[string]string{"uploadId": uploadID})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/uploads/complete", completeBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("complete status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "OK" {
		t.Fatalf("complete code = %q", resp.Code)
	}
	completeData, _ := json.Marshal(resp.Data)
	var complete map[string]any
	_ = json.Unmarshal(completeData, &complete)
	if complete["status"] != "completed" {
		t.Fatalf("status = %v", complete["status"])
	}
}

func TestUploadInitInvalidPurpose(t *testing.T) {
	router, _ := newTestRouter(t)
	body, _ := json.Marshal(map[string]any{
		"purpose": "invalid",
		"items":   []map[string]string{{"clientRef": "c1"}},
	})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/uploads/init", body, "usr_bad"))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}
