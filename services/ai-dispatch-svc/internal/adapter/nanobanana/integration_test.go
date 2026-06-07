package nanobanana

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
		if r.Header.Get("X-Vertex-AI-Data-Usage") != "no-training" {
			t.Error("expected no-training header")
		}
		body, _ := io.ReadAll(r.Body)
		var req editImageRequest
		if err := json.Unmarshal(body, &req); err != nil {
			t.Fatalf("unmarshal body: %v", err)
		}
		if req.Prompt == "" || req.ImageURL == "" {
			t.Fatalf("unexpected request: %+v", req)
		}

		_ = json.NewEncoder(w).Encode(editImageResponse{
			Images: []struct {
				URL string `json:"url"`
			}{{URL: "https://vendor.example.com/edited.png"}},
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:           "test-key",
		ProjectID:        "test-project",
		Endpoint:         server.URL,
		ModelID:          "imagen-3.0-capability-001",
		ObjectURLPrefix:  "https://s3.example.com",
		NoTrainingOptOut: true,
		HTTPClient:       server.Client(),
	})

	out, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageEdit,
		Region:     model.RegionOS,
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
		_ = json.NewEncoder(w).Encode(editImageResponse{
			Error: struct {
				Code    int    `json:"code"`
				Message string `json:"message"`
				Status  string `json:"status"`
			}{Status: "RESOURCE_EXHAUSTED", Message: "quota exceeded"},
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		ProjectID:  "test-project",
		Endpoint:   server.URL,
		ModelID:    "imagen-3.0-capability-001",
		HTTPClient: server.Client(),
	})

	_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "ghibli_kid",
		Capability: model.CapabilityImageEdit,
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
		_ = json.NewEncoder(w).Encode(editImageResponse{
			Error: struct {
				Code    int    `json:"code"`
				Message string `json:"message"`
				Status  string `json:"status"`
			}{Status: "FACE_NOT_DETECTED", Message: "face not detected"},
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		ProjectID:  "test-project",
		Endpoint:   server.URL,
		ModelID:    "imagen-3.0-capability-001",
		HTTPClient: server.Client(),
	})

	_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "photo_restore",
		Capability: model.CapabilityImageEdit,
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
