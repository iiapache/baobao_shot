package rest

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/config"
	"github.com/baobao/notification-svc/internal/store"
)

func TestHealthLive(t *testing.T) {
	st := store.NewMemoryStore()
	apnsClient, _ := apns.NewClient(apns.Config{})
	handler := NewRouter(&config.Config{ServiceName: "notification-svc"}, st, apnsClient)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
}

func TestReady(t *testing.T) {
	st := store.NewMemoryStore()
	apnsClient, _ := apns.NewClient(apns.Config{})
	handler := NewRouter(&config.Config{ServiceName: "notification-svc"}, st, apnsClient)

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
}
