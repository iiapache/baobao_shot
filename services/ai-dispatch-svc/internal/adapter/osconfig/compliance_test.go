package osconfig

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter/gptimage2"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/nanobanana"
)

func TestCompliance_OpenAINoTrainingHeader(t *testing.T) {
	var gotHeader string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotHeader = r.Header.Get("OpenAI-Data-Collection-Opt-Out")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"data":[{"url":"https://example.com/out.png"}]}`))
	}))
	defer server.Close()

	client := &gptimage2.HTTPClient{
		APIKey:           "sk-test",
		BaseURL:          server.URL,
		ModelID:          "gpt-image-1",
		NoTrainingOptOut: true,
		HTTP:             server.Client(),
	}
	if _, err := client.Generate(context.Background(), gptimage2.VendorRequest{
		ModelID:    "gpt-image-1",
		Prompt:     "test",
		OutputSize: "1024x1024",
	}); err != nil {
		t.Fatalf("Generate() error = %v", err)
	}
	if gotHeader != "true" {
		t.Fatalf("OpenAI-Data-Collection-Opt-Out = %q, want true", gotHeader)
	}
}

func TestCompliance_GoogleNoTrainingHeader(t *testing.T) {
	var gotHeader string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotHeader = r.Header.Get("X-Vertex-AI-Data-Usage")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"images":[{"url":"https://example.com/out.png"}]}`))
	}))
	defer server.Close()

	client := &nanobanana.HTTPClient{
		APIKey:           "g-test",
		ProjectID:        "proj-test",
		Endpoint:         server.URL,
		ModelID:          "imagen-3.0-capability-001",
		NoTrainingOptOut: true,
		HTTP:             server.Client(),
	}
	if _, err := client.Edit(context.Background(), nanobanana.VendorRequest{
		ModelID:  "imagen-3.0-capability-001",
		Prompt:   "test",
		ImageURL: "https://example.com/in.png",
	}); err != nil {
		t.Fatalf("Edit() error = %v", err)
	}
	if gotHeader != "no-training" {
		t.Fatalf("X-Vertex-AI-Data-Usage = %q, want no-training", gotHeader)
	}
}
