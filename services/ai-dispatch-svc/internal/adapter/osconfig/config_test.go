package osconfig

import (
	"context"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/gptimage2"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/nanobanana"
	"github.com/baobao/ai-dispatch-svc/internal/configclient"
)

func TestLoadFromEnv_OpenAIAPIBase(t *testing.T) {
	t.Setenv("OPENAI_API_BASE", "https://contract.openai.example/v1")
	t.Setenv("OPENAI_BASE_URL", "https://ignored.example/v1")
	t.Setenv("GOOGLE_API_BASE", "https://contract.vertex.example")

	cfg := LoadFromEnv()
	if cfg.OpenAIBaseURL != "https://contract.openai.example/v1" {
		t.Fatalf("OpenAIBaseURL = %q", cfg.OpenAIBaseURL)
	}
	if cfg.GoogleAPIBase != "https://contract.vertex.example" {
		t.Fatalf("GoogleAPIBase = %q", cfg.GoogleAPIBase)
	}
}

func TestLoadFromEnv_FallbackOpenAIBaseURL(t *testing.T) {
	t.Setenv("OPENAI_API_BASE", "")
	t.Setenv("OPENAI_BASE_URL", "https://legacy.openai.example/v1")

	cfg := LoadFromEnv()
	if cfg.OpenAIBaseURL != "https://legacy.openai.example/v1" {
		t.Fatalf("OpenAIBaseURL = %q, want legacy fallback", cfg.OpenAIBaseURL)
	}
}

func TestResolveNoTrainingOptOut_FromEnv(t *testing.T) {
	t.Setenv("OPENAI_NO_TRAINING_HEADER", "1")
	cfg := LoadFromEnv()
	if !ResolveNoTrainingOptOut(context.Background(), cfg, nil) {
		t.Fatal("expected opt-out true from env")
	}
}

func TestResolveNoTrainingOptOut_FromConfigSvc(t *testing.T) {
	t.Setenv("OPENAI_NO_TRAINING_HEADER", "")
	cfg := LoadFromEnv()
	stub := configclient.NewStub(map[string]configclient.FeatureResult{
		FeatureOSTrainingOptOut: {Enabled: true},
	})
	if !ResolveNoTrainingOptOut(context.Background(), cfg, stub) {
		t.Fatal("expected opt-out true from config-svc flag")
	}
}

func TestBuildOSAdapters_UsesComplianceEndpoints(t *testing.T) {
	adapters := BuildOSAdapters(Settings{
		OpenAIBaseURL:    "https://contract.openai.example/v1",
		GoogleAPIBase:    "https://contract.vertex.example",
		OpenAIAPIKey:     "sk-test",
		GoogleAPIKey:     "g-test",
		GoogleProjectID:  "proj-test",
		NoTrainingOptOut: true,
		MockMode:         false,
	})
	if len(adapters) != 2 {
		t.Fatalf("adapter count = %d, want 2", len(adapters))
	}

	var gpt *gptimage2.Adapter
	var nano *nanobanana.Adapter
	for _, a := range adapters {
		switch a.Name() {
		case "GptImage2Adapter":
			gpt, _ = a.(*gptimage2.Adapter)
		case "NanoBananaAdapter":
			nano, _ = a.(*nanobanana.Adapter)
		}
	}
	if gpt == nil || nano == nil {
		t.Fatal("expected GptImage2Adapter and NanoBananaAdapter")
	}
}

func TestEnrichAdapters_ReplacesOSStubs(t *testing.T) {
	t.Setenv("OS_ADAPTER_MOCK_MODE", "true")
	t.Setenv("OPENAI_NO_TRAINING_HEADER", "1")

	base := []adapter.ModelAdapter{
		&adapter.StubAdapter{AdapterName: "SeedreamAdapter"},
		&adapter.StubAdapter{AdapterName: "GptImage2Adapter"},
		&adapter.StubAdapter{AdapterName: "NanoBananaAdapter"},
	}
	enriched := EnrichAdapters(base, context.Background(), nil)

	var gptName, nanoName string
	for _, a := range enriched {
		switch a.Name() {
		case "GptImage2Adapter":
			gptName = a.Name()
		case "NanoBananaAdapter":
			nanoName = a.Name()
		}
	}
	if gptName == "" || nanoName == "" {
		t.Fatal("expected OS adapters after enrich")
	}
}
