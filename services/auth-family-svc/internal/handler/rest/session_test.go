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

func sessionTestRouter(t *testing.T) http.Handler {
	t.Helper()
	cfg := &config.Config{
		ServiceName:      "auth-family-svc",
		MockAppleVerify:  true,
		JWTSigningSecret: "session-test-secret",
	}
	mem := store.NewMemoryStore()
	backend := store.NewBackend(cfg, mem, nil)
	return NewRouter(cfg, backend)
}

func TestRefreshRotationHTTP(t *testing.T) {
	router := sessionTestRouter(t)

	loginPair := appleLoginTokens(t, router, "apple-refresh-user")

	refreshBody, _ := json.Marshal(map[string]string{"refreshToken": loginPair.Refresh})
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/refresh", bytes.NewReader(refreshBody))
	setRequiredHeaders(req)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("refresh status = %d, body=%s", rec.Code, rec.Body.String())
	}

	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	newRefresh := data["refreshToken"].(string)

	oldReq := httptest.NewRequest(http.MethodPost, "/v1/auth/refresh", bytes.NewReader(refreshBody))
	setRequiredHeaders(oldReq)
	oldRec := httptest.NewRecorder()
	router.ServeHTTP(oldRec, oldReq)
	if oldRec.Code != http.StatusUnauthorized {
		t.Fatalf("old refresh status = %d, want 401", oldRec.Code)
	}
	var oldResp apiResponse
	_ = json.Unmarshal(oldRec.Body.Bytes(), &oldResp)
	if oldResp.Code != "AUTH_REFRESH_INVALID" {
		t.Fatalf("old refresh code = %q", oldResp.Code)
	}

	newBody, _ := json.Marshal(map[string]string{"refreshToken": newRefresh})
	newReq := httptest.NewRequest(http.MethodPost, "/v1/auth/refresh", bytes.NewReader(newBody))
	setRequiredHeaders(newReq)
	newRec := httptest.NewRecorder()
	router.ServeHTTP(newRec, newReq)
	if newRec.Code != http.StatusOK {
		t.Fatalf("new refresh status = %d, body=%s", newRec.Code, newRec.Body.String())
	}
}

func TestLogoutBlacklistsAccessTokenHTTP(t *testing.T) {
	router := sessionTestRouter(t)
	pair := appleLoginTokens(t, router, "apple-logout-user")

	req := httptest.NewRequest(http.MethodPost, "/v1/account/logout", nil)
	req.Header.Set("Authorization", "Bearer "+pair.Access)
	setRequiredHeaders(req)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("logout status = %d, body=%s", rec.Code, rec.Body.String())
	}

	protected := httptest.NewRequest(http.MethodGet, "/v1/families", nil)
	protected.Header.Set("Authorization", "Bearer "+pair.Access)
	setRequiredHeaders(protected)
	protectedRec := httptest.NewRecorder()
	router.ServeHTTP(protectedRec, protected)
	if protectedRec.Code != http.StatusUnauthorized {
		t.Fatalf("protected with revoked token status = %d, want 401", protectedRec.Code)
	}
}

type loginTokens struct {
	Access  string
	Refresh string
}

func appleLoginTokens(t *testing.T, router http.Handler, appleSub string) loginTokens {
	t.Helper()
	payload := map[string]string{
		"identityToken":     authTestToken(appleSub),
		"authorizationCode": "c-session",
		"nickname":          "会话测试",
		"region":            "cn",
	}
	raw, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/apple", bytes.NewReader(raw))
	setRequiredHeaders(req)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("apple login status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	return loginTokens{
		Access:  data["accessToken"].(string),
		Refresh: data["refreshToken"].(string),
	}
}
