package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/consent"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestRequireChildConsent(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := t.Context()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_mw", AppleSub: "apple-mw", Region: "cn",
	})
	svc := consent.NewService(mem)

	called := false
	handler := RequireChildConsent(svc)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodPost, "/v1/families", nil)
	req = req.WithContext(withUserID(req.Context(), user.ID))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want 422", rec.Code)
	}
	var resp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &resp)
	if resp["code"] != "ACCOUNT_CONSENT_REQUIRED" {
		t.Fatalf("code = %q", resp["code"])
	}
	if called {
		t.Fatal("handler should not be called without consent")
	}

	_, _ = svc.RecordChildDataConsent(ctx, user.ID, consent.CurrentConsentVersion, true, "127.0.0.1", "d1")
	called = false
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("after consent status = %d body = %s", rec.Code, rec.Body.String())
	}
	if !called {
		t.Fatal("handler should be called with valid consent")
	}
}

func TestRequireChildConsentRejectsStaleVersion(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := t.Context()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_stale", AppleSub: "apple-stale", Region: "cn",
	})
	svc := consent.NewService(mem)

	_, err := mem.RecordChildConsent(ctx, store.RecordChildConsentInput{
		UserID:   user.ID,
		Version:  "child_consent_v0",
		AgreedAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatalf("seed stale consent: %v", err)
	}

	called := false
	handler := RequireChildConsent(svc)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodPost, "/v1/families", nil)
	req = req.WithContext(withUserID(req.Context(), user.ID))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want 422 for stale version", rec.Code)
	}
	var resp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &resp)
	if resp["code"] != "ACCOUNT_CONSENT_REQUIRED" {
		t.Fatalf("code = %q, want ACCOUNT_CONSENT_REQUIRED", resp["code"])
	}
	if called {
		t.Fatal("handler should not be called with stale consent version")
	}
}

func withUserID(ctx context.Context, userID string) context.Context {
	return contextWithUserID(ctx, userID)
}

func contextWithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userIDKey, userID)
}
