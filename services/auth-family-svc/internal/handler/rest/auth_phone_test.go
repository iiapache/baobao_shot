package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/store"
)

func testBackend(t *testing.T) *store.Backend {
	t.Helper()
	return &store.Backend{
		Store:        store.NewMemoryStore(),
		Verification: store.NewMemoryVerificationStore(),
	}
}

func TestPhoneSendCodeAndLoginHTTP(t *testing.T) {
	backend := testBackend(t)
	cfg := &config.Config{ServiceName: "auth-family-svc", MockAppleVerify: true}
	router := NewRouter(cfg, backend)

	sendBody := bytes.NewBufferString(`{"phone":"13800138001"}`)
	sendReq := httptest.NewRequest(http.MethodPost, "/v1/auth/phone/code", sendBody)
	sendRec := httptest.NewRecorder()
	router.ServeHTTP(sendRec, sendReq)
	if sendRec.Code != http.StatusOK {
		t.Fatalf("send status = %d, body=%s", sendRec.Code, sendRec.Body.String())
	}

	now := time.Now().UTC()
	if err := backend.Verification.SaveCode(sendReq.Context(), "13800138001", "cn", "123456", now, now.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}

	loginPayload := map[string]string{"phone": "13800138001", "code": "123456"}
	raw, _ := json.Marshal(loginPayload)
	loginReq := httptest.NewRequest(http.MethodPost, "/v1/auth/phone/login", bytes.NewReader(raw))
	loginRec := httptest.NewRecorder()
	router.ServeHTTP(loginRec, loginReq)
	if loginRec.Code != http.StatusOK {
		t.Fatalf("login status = %d, body=%s", loginRec.Code, loginRec.Body.String())
	}

	var resp apiResponse
	if err := json.Unmarshal(loginRec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %q", resp.Code)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("missing data")
	}
	if data["isNewUser"] != true {
		t.Fatalf("isNewUser = %v", data["isNewUser"])
	}
}

func TestPhoneSendCodeRateLimitHTTP(t *testing.T) {
	backend := testBackend(t)
	cfg := &config.Config{ServiceName: "auth-family-svc", MockAppleVerify: true}
	router := NewRouter(cfg, backend)

	body := []byte(`{"phone":"13800138009"}`)
	req1 := httptest.NewRequest(http.MethodPost, "/v1/auth/phone/code", bytes.NewReader(body))
	rec1 := httptest.NewRecorder()
	router.ServeHTTP(rec1, req1)
	if rec1.Code != http.StatusOK {
		t.Fatalf("first send status = %d, body=%s", rec1.Code, rec1.Body.String())
	}

	req2 := httptest.NewRequest(http.MethodPost, "/v1/auth/phone/code", bytes.NewReader(body))
	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, req2)
	if rec2.Code != http.StatusTooManyRequests {
		t.Fatalf("resend within 60s status = %d, want 429, body=%s", rec2.Code, rec2.Body.String())
	}

	var resp apiResponse
	if err := json.Unmarshal(rec2.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Code != "COMMON_RATE_LIMIT" {
		t.Fatalf("code = %q, want COMMON_RATE_LIMIT", resp.Code)
	}
}
