package rest

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
)

func TestHealthLive(t *testing.T) {
	h := NewHealthHandler("credit-sub-ad-svc")
	r := chi.NewRouter()
	r.Get("/health", h.Live)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}

func TestHealthReady(t *testing.T) {
	h := NewHealthHandler("credit-sub-ad-svc")
	r := chi.NewRouter()
	r.Get("/ready", h.Ready)

	h.SetReady(false)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/ready", nil))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("not ready status = %d, want 503", rec.Code)
	}

	h.SetReady(true)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/ready", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("ready status = %d, want 200", rec.Code)
	}
}
