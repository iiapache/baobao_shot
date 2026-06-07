package tongyi

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

func TestIntegration_HTTPClient_AsyncSuccess(t *testing.T) {
	var pollCount int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodPost && strings.HasSuffix(r.URL.Path, "image-synthesis"):
			if r.Header.Get("X-DashScope-Async") != "enable" {
				t.Fatal("expected async header")
			}
			body, _ := io.ReadAll(r.Body)
			var req wan25Request
			if err := json.Unmarshal(body, &req); err != nil {
				t.Fatalf("unmarshal body: %v", err)
			}
			if req.Input.Prompt == "" || len(req.Input.Images) != 1 {
				t.Fatalf("unexpected request: %+v", req)
			}
			_ = json.NewEncoder(w).Encode(createTaskResponse{
				Output: struct {
					TaskID     string `json:"task_id"`
					TaskStatus string `json:"task_status"`
					Results    []struct {
						URL string `json:"url"`
					} `json:"results"`
				}{TaskID: "task-123", TaskStatus: "PENDING"},
			})
		case r.Method == http.MethodGet && strings.Contains(r.URL.Path, "/tasks/task-123"):
			pollCount++
			status := "RUNNING"
			if pollCount >= 2 {
				status = "SUCCEEDED"
			}
			resp := createTaskResponse{}
			resp.Output.TaskID = "task-123"
			resp.Output.TaskStatus = status
			if status == "SUCCEEDED" {
				resp.Output.Results = []struct {
					URL string `json:"url"`
				}{{URL: "https://vendor.example.com/edited.png"}}
			}
			_ = json.NewEncoder(w).Encode(resp)
		default:
			t.Fatalf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:          "test-key",
		Endpoint:        server.URL,
		ModelID:         "wan2.5-i2i-preview",
		ObjectURLPrefix: "https://oss.example.com",
		HTTPClient:      server.Client(),
	})

	out, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "style_swap",
		Capability: model.CapabilityImageEdit,
		Region:     model.RegionCN,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/kid.jpg"},
	})
	if err != nil {
		t.Fatalf("Invoke() error = %v", err)
	}
	if !strings.HasPrefix(out.ObjectKey, "ai-out/") {
		t.Fatalf("objectKey = %q", out.ObjectKey)
	}
	if pollCount < 2 {
		t.Fatalf("pollCount = %d, want >= 2", pollCount)
	}
}

func TestIntegration_HTTPClient_VendorRateLimit(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
		_ = json.NewEncoder(w).Encode(createTaskResponse{
			Code:    "Throttling",
			Message: "qps limit",
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		Endpoint:   server.URL,
		ModelID:    "wan2.5-i2i-preview",
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

func TestIntegration_HTTPClient_ContentPolicy(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(createTaskResponse{
			Output: struct {
				TaskID     string `json:"task_id"`
				TaskStatus string `json:"task_status"`
				Results    []struct {
					URL string `json:"url"`
				} `json:"results"`
			}{TaskID: "task-fail", TaskStatus: "FAILED"},
			Code:    "DataInspectionFailed",
			Message: "content policy",
		})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		Endpoint:   server.URL,
		ModelID:    "wan2.5-i2i-preview",
		HTTPClient: server.Client(),
	})

	_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "photo_restore",
		Capability: model.CapabilityImageEdit,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/old.jpg"},
	})
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeContentPolicy {
		t.Fatalf("code = %v, want MODEL_CONTENT_POLICY", ae)
	}
	if adapter.IsRetryable(err) {
		t.Fatal("content policy should not retry")
	}
}

func TestIntegration_ModelAdapterContract(t *testing.T) {
	var _ adapter.ModelAdapter = NewAdapter(Config{MockMode: true})
}
