package rest_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/handler/rest"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestInternalVerify_NoToken(t *testing.T) {
	router := rest.NewRouter(&config.Config{
		ServiceName:      "auth-family-svc",
		JWTSigningSecret: "verify-test-secret",
	}, &store.Backend{
		Store:        store.NewMemoryStore(),
		Verification: store.NewMemoryVerificationStore(),
	})

	req := httptest.NewRequest(http.MethodGet, "/internal/verify", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}

	var resp map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp["code"] != "AUTH_TOKEN_EXPIRED" {
		t.Fatalf("code = %v, want AUTH_TOKEN_EXPIRED", resp["code"])
	}
	if resp["requestId"] == nil || resp["requestId"] == "" {
		t.Fatal("expected requestId in 401 body")
	}
}

func TestInternalVerify_DevToken(t *testing.T) {
	router := rest.NewRouter(&config.Config{
		ServiceName:      "auth-family-svc",
		JWTSigningSecret: "verify-test-secret",
	}, &store.Backend{
		Store:        store.NewMemoryStore(),
		Verification: store.NewMemoryVerificationStore(),
	})

	req := httptest.NewRequest(http.MethodGet, "/internal/verify", nil)
	req.Header.Set("Authorization", "Bearer dev")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if got := rec.Header().Get("X-User-Id"); got != "usr_dev" {
		t.Fatalf("X-User-Id = %q, want usr_dev", got)
	}
}

func TestInternalVerify_InvalidToken(t *testing.T) {
	router := rest.NewRouter(&config.Config{
		ServiceName:      "auth-family-svc",
		JWTSigningSecret: "verify-test-secret",
	}, &store.Backend{
		Store:        store.NewMemoryStore(),
		Verification: store.NewMemoryVerificationStore(),
	})

	req := httptest.NewRequest(http.MethodGet, "/internal/verify", nil)
	req.Header.Set("Authorization", "Bearer not-a-jwt")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}
