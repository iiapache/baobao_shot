package gptimage2

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

func TestIntegration_HTTPClient_EditSuccess(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != editsPath {
			t.Fatalf("path = %s, want %s", r.URL.Path, editsPath)
		}
		if r.Header.Get("OpenAI-Data-Collection-Opt-Out") != "true" {
			t.Error("expected no-training header")
		}
		body, _ := io.ReadAll(r.Body)
		var req editRequest
		if err := json.Unmarshal(body, &req); err != nil {
			t.Fatalf("unmarshal body: %v", err)
		}
		if req.Prompt == "" || req.ImageURL == "" {
			t.Fatalf("unexpected request: %+v", req)
		}

		_ = json.NewEncoder(w).Encode(openAIImageResponse{
			Data: []struct {
				URL string `json:"url"`
			}{{URL: "https://vendor.example.com/edited.png"}},
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:           "test-key",
		OrgID:            "org-test",
		BaseURL:          server.URL,
		ModelID:          "gpt-image-1",
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

func TestIntegration_HTTPClient_GenerateSuccess(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != generationsPath {
			t.Fatalf("path = %s, want %s", r.URL.Path, generationsPath)
		}
		body, _ := io.ReadAll(r.Body)
		var req generationRequest
		if err := json.Unmarshal(body, &req); err != nil {
			t.Fatalf("unmarshal body: %v", err)
		}
		if req.Prompt == "" || req.Model == "" {
			t.Fatalf("unexpected request: %+v", req)
		}

		_ = json.NewEncoder(w).Encode(openAIImageResponse{
			Data: []struct {
				URL string `json:"url"`
			}{{URL: "https://vendor.example.com/generated.png"}},
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		BaseURL:    server.URL,
		ModelID:    "gpt-image-1",
		HTTPClient: server.Client(),
	})

	out, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "gpt_portrait",
		Capability: model.CapabilityImageGen,
		Region:     model.RegionOS,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/ref.jpg"},
	})
	if err != nil {
		t.Fatalf("Invoke() error = %v", err)
	}
	if !strings.HasPrefix(out.ObjectKey, "ai-out/gpt_portrait_") {
		t.Fatalf("objectKey = %q", out.ObjectKey)
	}
}

func TestIntegration_HTTPClient_VendorRateLimit(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
		_ = json.NewEncoder(w).Encode(openAIImageResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				Type    string `json:"type"`
			}{Code: "rate_limit_exceeded", Message: "rate limit"},
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		BaseURL:    server.URL,
		ModelID:    "gpt-image-1",
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
		_ = json.NewEncoder(w).Encode(openAIImageResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				Type    string `json:"type"`
			}{Code: "face_not_detected", Message: "face not detected"},
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		BaseURL:    server.URL,
		ModelID:    "gpt-image-1",
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
