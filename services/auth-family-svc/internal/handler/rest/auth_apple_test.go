package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/store"
)

func testRouter(t *testing.T) http.Handler {
	t.Helper()
	cfg := &config.Config{
		ServiceName:     "auth-family-svc",
		MockAppleVerify: true,
	}
	backend := store.NewBackend(cfg, store.NewMemoryStore(), nil)
	return NewRouter(cfg, backend)
}

func setRequiredHeaders(req *http.Request) {
	req.Header.Set("X-Region", "cn")
	req.Header.Set("X-App-Version", "1.0.0")
	req.Header.Set("X-Device-Id", "device-test-1")
}

func TestAppleLoginRequiresHeaders(t *testing.T) {
	router := testRouter(t)

	body := bytes.NewBufferString(`{"identityToken":"apple-sub-1","authorizationCode":"c-1","region":"cn"}`)
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/apple", body)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

func TestAppleLoginNewUserHTTP(t *testing.T) {
	router := testRouter(t)

	payload := map[string]string{
		"identityToken":     authTestToken("apple-http-new"),
		"authorizationCode": "c-new",
		"nickname":          "测试用户",
		"region":            "cn",
	}
	raw, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/v1/auth/apple", bytes.NewReader(raw))
	setRequiredHeaders(req)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}

	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %q", resp.Code)
	}

	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	if data["isNewUser"] != true {
		t.Fatalf("isNewUser = %v, want true", data["isNewUser"])
	}
	profile, ok := data["profile"].(map[string]any)
	if !ok {
		t.Fatal("profile missing")
	}
	consents, ok := profile["consents"].(map[string]any)
	if !ok {
		t.Fatal("consents missing")
	}
	if consents["childData"] != false {
		t.Fatalf("childData = %v, want false", consents["childData"])
	}
}

func TestAppleLoginExistingUserHTTP(t *testing.T) {
	router := testRouter(t)
	token := authTestToken("apple-http-existing")

	for i := 0; i < 2; i++ {
		payload := map[string]string{
			"identityToken":     token,
			"authorizationCode": "c-loop",
			"region":            "cn",
		}
		raw, _ := json.Marshal(payload)

		req := httptest.NewRequest(http.MethodPost, "/v1/auth/apple", bytes.NewReader(raw))
		setRequiredHeaders(req)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("login %d status = %d", i, rec.Code)
		}

		var resp apiResponse
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatal(err)
		}
		data := resp.Data.(map[string]any)
		wantNew := i == 0
		if data["isNewUser"] != wantNew {
			t.Fatalf("login %d isNewUser = %v, want %v", i, data["isNewUser"], wantNew)
		}
		if i == 1 && data["userId"] == "" {
			t.Fatal("expected stable userId")
		}
	}
}

func authTestToken(sub string) string {
	return sub
}
