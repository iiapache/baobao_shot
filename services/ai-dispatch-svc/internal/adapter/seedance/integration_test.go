package seedance

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestIntegration_HTTPClient_AsyncSuccess(t *testing.T) {
	var mu sync.Mutex
	pollCount := 0

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		action := r.URL.Query().Get("Action")
		body, _ := io.ReadAll(r.Body)

		switch action {
		case submitAction:
			var req submitRequest
			if err := json.Unmarshal(body, &req); err != nil {
				t.Fatalf("unmarshal submit: %v", err)
			}
			if req.Frames != frames5Seconds {
				t.Fatalf("frames = %d, want %d", req.Frames, frames5Seconds)
			}
			if req.Format != outputFormatMP4 || req.Codec != outputCodecH264 {
				t.Fatalf("format/codec = %s/%s", req.Format, req.Codec)
			}
			_ = json.NewEncoder(w).Encode(vendorEnvelope{
				Code:    10000,
				Message: "success",
				Data:    json.RawMessage(`{"task_id":"task_123"}`),
			})
		case getResultAction:
			mu.Lock()
			pollCount++
			count := pollCount
			mu.Unlock()

			status := "generating"
			var data resultData
			if count >= 2 {
				status = "done"
				data = resultData{
					Status:   status,
					VideoURL: "https://vendor.example.com/generated/video.mp4",
					Format:   "mp4",
					Codec:    "h264",
				}
			} else {
				data = resultData{Status: status}
			}
			raw, _ := json.Marshal(data)
			_ = json.NewEncoder(w).Encode(vendorEnvelope{
				Code:    10000,
				Message: "success",
				Data:    raw,
			})
		default:
			t.Fatalf("unexpected action %s", action)
		}
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:          "test-key",
		Endpoint:        server.URL,
		ModelID:         "seedance_i2v_v1",
		ObjectURLPrefix: "https://oss.example.com",
		HTTPClient:      server.Client(),
		PollInterval:    10 * time.Millisecond,
	})

	out, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:           "video_walk",
		Capability:      model.CapabilityVideoGen,
		Region:          model.RegionCN,
		DurationSeconds: 5,
		Input:           model.TaskInput{ObjectKey: "ai-tmp/usr_1/kid.jpg"},
	})
	if err != nil {
		t.Fatalf("Invoke() error = %v", err)
	}
	if !strings.HasPrefix(out.ObjectKey, "ai-out/") || !strings.HasSuffix(out.ObjectKey, ".mp4") {
		t.Fatalf("objectKey = %q", out.ObjectKey)
	}

	mu.Lock()
	defer mu.Unlock()
	if pollCount < 2 {
		t.Fatalf("pollCount = %d, want >= 2", pollCount)
	}
}

func TestIntegration_HTTPClient_RejectNonH264(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		action := r.URL.Query().Get("Action")
		switch action {
		case submitAction:
			_ = json.NewEncoder(w).Encode(vendorEnvelope{
				Code: 10000,
				Data: json.RawMessage(`{"task_id":"task_1"}`),
			})
		case getResultAction:
			raw, _ := json.Marshal(resultData{
				Status:   "done",
				VideoURL: "https://vendor.example.com/video.mp4",
				Format:   "mp4",
				Codec:    "hevc",
			})
			_ = json.NewEncoder(w).Encode(vendorEnvelope{Code: 10000, Data: raw})
		}
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:       "test-key",
		Endpoint:     server.URL,
		ModelID:      "seedance_i2v_v1",
		HTTPClient:   server.Client(),
		PollInterval: time.Millisecond,
	})

	_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:           "video_walk",
		Capability:      model.CapabilityVideoGen,
		DurationSeconds: 5,
		Input:           model.TaskInput{ObjectKey: "ai-tmp/usr_1/kid.jpg"},
	})
	if err == nil {
		t.Fatal("expected error for non-h264 codec")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeInvalidInput {
		t.Fatalf("code = %v, want MODEL_INVALID_INPUT", ae)
	}
}

func TestIntegration_HTTPClient_VendorRateLimit(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
		_ = json.NewEncoder(w).Encode(vendorEnvelope{Code: 50411, Message: "qps limit"})
	}))
	defer server.Close()

	a := NewAdapter(Config{
		APIKey:     "test-key",
		Endpoint:   server.URL,
		ModelID:    "seedance_i2v_v1",
		HTTPClient: server.Client(),
	})

	_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:           "video_walk",
		Capability:      model.CapabilityVideoGen,
		DurationSeconds: 5,
		Input:           model.TaskInput{ObjectKey: "ai-tmp/usr_1/kid.jpg"},
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

func TestIntegration_ModelAdapterContract(t *testing.T) {
	var _ adapter.ModelAdapter = NewAdapter(Config{MockMode: true})
}
