package seedance

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
)

func TestHTTPClient_VideoTimeout5Minutes(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		action := r.URL.Query().Get("Action")
		switch action {
		case submitAction:
			_ = json.NewEncoder(w).Encode(vendorEnvelope{
				Code: 10000,
				Data: json.RawMessage(`{"task_id":"task_slow"}`),
			})
		case getResultAction:
			raw, _ := json.Marshal(resultData{Status: "generating"})
			_ = json.NewEncoder(w).Encode(vendorEnvelope{Code: 10000, Data: raw})
		}
	}))
	defer server.Close()

	client := &HTTPClient{
		APIKey:       "test-key",
		Endpoint:     server.URL,
		HTTP:         server.Client(),
		PollInterval: time.Millisecond,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	_, err := client.Generate(ctx, VendorRequest{
		ReqKey:   "seedance_i2v_v1",
		ImageURL: "https://oss.example.com/in.jpg",
		Prompt:   "test",
		Frames:   frames5Seconds,
		Format:   outputFormatMP4,
		Codec:    outputCodecH264,
	})
	if err == nil {
		t.Fatal("expected timeout error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeTransient {
		t.Fatalf("code = %v, want MODEL_TRANSIENT", ae)
	}
}

func TestVideoInvokeTimeoutConstant(t *testing.T) {
	if videoInvokeTimeout != 5*time.Minute {
		t.Fatalf("videoInvokeTimeout = %v, want 5m", videoInvokeTimeout)
	}
}
