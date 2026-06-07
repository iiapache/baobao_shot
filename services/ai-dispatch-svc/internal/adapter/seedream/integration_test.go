package seedream

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestIntegration_HTTPClient_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("Action") != vendorAction {
			t.Errorf("action = %s", r.URL.Query().Get("Action"))
		}
		body, _ := io.ReadAll(r.Body)
		var req cvProcessRequest
		if err := json.Unmarshal(body, &req); err != nil {
			t.Fatalf("unmarshal body: %v", err)
		}
		if req.Prompt == "" || len(req.ImageURLs) != 1 {
			t.Fatalf("unexpected request: %+v", req)
		}

		_ = json.NewEncoder(w).Encode(cvProcessResponse{
			Code:    10000,
			Message: "success",
			Data: struct {
				ImageURLs []string `json:"image_urls"`
			}{ImageURLs: []string{"https://vendor.example.com/generated.png"}},
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:          "test-key",
		Endpoint:        server.URL,
		ModelID:         "seedream-v3",
		ObjectURLPrefix: "https://oss.example.com",
		HTTPClient:      server.Client(),
	})

	out, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "storybook_gen",
		Capability: model.CapabilityImageGen,
		Region:     model.RegionCN,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/kid.jpg"},
	})
	if err != nil {
		t.Fatalf("Invoke() error = %v", err)
	}
	if !strings.HasPrefix(out.ObjectKey, "ai-out/") {
		t.Fatalf("objectKey = %q", out.ObjectKey)
	}
}

func TestIntegration_HTTPClient_VendorRateLimit(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
		_ = json.NewEncoder(w).Encode(cvProcessResponse{Code: 50411, Message: "qps limit"})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		Endpoint:   server.URL,
		ModelID:    "seedream-v3",
		HTTPClient: server.Client(),
	})

	_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "ghibli_kid",
		Capability: model.CapabilityImageGen,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/kid.jpg"},
	})
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeRateLimited {
		t.Fatalf("code = %v, want MODEL_RATE_LIMITED", ae)
	}
	if !adapter.IsRetryable(err) {
		t.Fatal("rate limit should be retryable")
	}
}

func TestIntegration_HTTPClient_FaceNotDetected(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(cvProcessResponse{Code: 60208, Message: "face not detected"})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		Endpoint:   server.URL,
		ModelID:    "seedream-v3",
		HTTPClient: server.Client(),
	})

	_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "seedream_style",
		Capability: model.CapabilityImageGen,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/no-face.jpg"},
	})
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeFaceNotFound {
		t.Fatalf("code = %v, want MODEL_FACE_NOT_FOUND", ae)
	}
	if adapter.IsRetryable(err) {
		t.Fatal("face not found should not retry")
	}
}

func TestIntegration_ModelAdapterContract(t *testing.T) {
	var _ adapter.ModelAdapter = NewAdapter(Config{MockMode: true})
}
