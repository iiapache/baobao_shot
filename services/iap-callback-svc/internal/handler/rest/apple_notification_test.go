package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/iap-callback-svc/internal/config"
	"github.com/baobao/iap-callback-svc/internal/idempotency"
	"github.com/baobao/iap-callback-svc/internal/kafka"
	"github.com/baobao/iap-callback-svc/internal/processor"
)

func TestAppleNotificationSandboxMock(t *testing.T) {
	producer := kafka.NewStubProducer()
	proc := processor.NewService(idempotency.NewMemoryStore(), producer, kafka.TopicIAPEvents)
	router := NewRouter(&config.Config{ServiceName: "iap-callback-svc"}, proc)

	body, _ := json.Marshal(map[string]string{
		"signedPayload": "mock-asn:REFUND:notif-http-1:mock:2000000123456789:credit_pack_60",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/apple/notifications", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if len(producer.Messages(kafka.TopicIAPEvents)) != 1 {
		t.Fatal("expected kafka event published")
	}
}

func TestAppleNotificationInvalidPayload(t *testing.T) {
	proc := processor.NewService(idempotency.NewMemoryStore(), kafka.NewStubProducer(), kafka.TopicIAPEvents)
	router := NewRouter(nil, proc)

	req := httptest.NewRequest(http.MethodPost, "/v1/apple/notifications", bytes.NewReader([]byte(`{}`)))
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}
