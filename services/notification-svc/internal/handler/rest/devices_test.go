package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/config"
	"github.com/baobao/notification-svc/internal/store"
)

func newTestRouter(t *testing.T) http.Handler {
	t.Helper()
	st := store.NewMemoryStore()
	apnsClient, err := apns.NewClient(apns.Config{Cleaner: nil})
	if err != nil {
		t.Fatal(err)
	}
	cfg := &config.Config{ServiceName: "notification-svc", DebugEndpoints: true}
	return NewRouter(cfg, st, apnsClient)
}

func validToken() string {
	return "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
}

func TestRegisterDevice(t *testing.T) {
	handler := newTestRouter(t)
	body, _ := json.Marshal(map[string]string{
		"deviceId":   "dev_1",
		"apnsToken":  validToken(),
		"appVersion": "1.0.0",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/notifications/devices", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:usr_test")
	req.Header.Set("X-Region", "cn")

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rr.Code, rr.Body.String())
	}

	var resp apiResponse
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %s", resp.Code)
	}
}

func TestRegisterDeviceUnauthorized(t *testing.T) {
	handler := newTestRouter(t)
	body, _ := json.Marshal(map[string]string{"deviceId": "dev_1", "apnsToken": validToken()})
	req := httptest.NewRequest(http.MethodPost, "/v1/notifications/devices", bytes.NewReader(body))
	req.Header.Set("X-Region", "cn")

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d", rr.Code)
	}
}

func TestUnregisterDevice(t *testing.T) {
	handler := newTestRouter(t)
	body, _ := json.Marshal(map[string]string{
		"deviceId":  "dev_2",
		"apnsToken": validToken(),
	})
	reg := httptest.NewRequest(http.MethodPost, "/v1/notifications/devices", bytes.NewReader(body))
	reg.Header.Set("Authorization", "Bearer dev:usr_del")
	reg.Header.Set("X-Region", "os")
	regRR := httptest.NewRecorder()
	handler.ServeHTTP(regRR, reg)
	if regRR.Code != http.StatusOK {
		t.Fatalf("register status = %d", regRR.Code)
	}

	req := httptest.NewRequest(http.MethodDelete, "/v1/notifications/devices/dev_2", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_del")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rr.Code, rr.Body.String())
	}
}

func TestCleanupInvalidToken(t *testing.T) {
	handler := newTestRouter(t)
	token := validToken()

	regBody, _ := json.Marshal(map[string]string{"deviceId": "dev_c", "apnsToken": token})
	reg := httptest.NewRequest(http.MethodPost, "/v1/notifications/devices", bytes.NewReader(regBody))
	reg.Header.Set("Authorization", "Bearer dev:usr_clean")
	reg.Header.Set("X-Region", "cn")
	handler.ServeHTTP(httptest.NewRecorder(), reg)

	body, _ := json.Marshal(map[string]string{"apnsToken": token})
	req := httptest.NewRequest(http.MethodPost, "/v1/internal/notifications/tokens/cleanup", bytes.NewReader(body))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rr.Code, rr.Body.String())
	}
}

func TestAPNsPingDemo(t *testing.T) {
	handler := newTestRouter(t)
	body, _ := json.Marshal(map[string]string{
		"device_token": validToken(),
		"title":        "T5.7",
		"body":         "APNs stub demo",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/debug/apns-ping", bytes.NewReader(body))
	req.Header.Set("X-Region", "cn")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rr.Code, rr.Body.String())
	}

	var resp apiResponse
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %s", resp.Code)
	}
}

func TestAPNsPingInvalidToken(t *testing.T) {
	handler := newTestRouter(t)
	body, _ := json.Marshal(map[string]string{
		"device_token": "invalid:" + validToken(),
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/debug/apns-ping", bytes.NewReader(body))
	req.Header.Set("X-Region", "os")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, body = %s", rr.Code, rr.Body.String())
	}
}
