package cnconfig

import (
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/seedream"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/tongyi"
)

func TestLoadFromEnv_DashScopeAndBytedance(t *testing.T) {
	t.Setenv("CN_ADAPTER_MOCK_MODE", "false")
	t.Setenv("DASHSCOPE_ENDPOINT", "http://mock-ai.example:8080")
	t.Setenv("DASHSCOPE_API_KEY", "ds-key")
	t.Setenv("BYTEDANCE_ENDPOINT", "http://mock-ai.example:8080")
	t.Setenv("BYTEDANCE_API_KEY", "bd-key")
	t.Setenv("BYTEDANCE_API_SECRET", "bd-secret")
	t.Setenv("WANXIANG_MODEL_ID", "wan2.5-i2i-preview")
	t.Setenv("SEEDREAM_MODEL_ID", "seedream-v3")

	cfg := LoadFromEnv()
	if cfg.MockMode {
		t.Fatal("MockMode should be false")
	}
	if cfg.DashScopeEndpoint != "http://mock-ai.example:8080" {
		t.Fatalf("DashScopeEndpoint = %q", cfg.DashScopeEndpoint)
	}
	if cfg.BytedanceAPIKey != "bd-key" || cfg.BytedanceAPISecret != "bd-secret" {
		t.Fatalf("bytedance creds = %q / %q", cfg.BytedanceAPIKey, cfg.BytedanceAPISecret)
	}
}

func TestBuildCNAdapters_LiveWithMockAIEndpoints(t *testing.T) {
	adapters := BuildCNAdapters(Settings{
		MockMode:          false,
		DashScopeAPIKey:   "ds-key",
		DashScopeEndpoint: "http://mock-ai.example:8080",
		BytedanceAPIKey:   "bd-key",
		BytedanceEndpoint: "http://mock-ai.example:8080",
		WanxiangModelID:   "wan2.5-i2i-preview",
		SeedreamModelID:   "seedream-v3",
	})
	if len(adapters) != 4 {
		t.Fatalf("adapter count = %d, want 4", len(adapters))
	}

	var seedreamAdapter *seedream.Adapter
	var tongyiAdapter *tongyi.Adapter
	for _, a := range adapters {
		switch a.Name() {
		case "SeedreamAdapter":
			seedreamAdapter, _ = a.(*seedream.Adapter)
		case "TongyiWanxiangAdapter":
			tongyiAdapter, _ = a.(*tongyi.Adapter)
		}
	}
	if seedreamAdapter == nil || tongyiAdapter == nil {
		t.Fatal("expected SeedreamAdapter and TongyiWanxiangAdapter")
	}
}

func TestBuildCNAdapters_FallsBackToMockWithoutKeys(t *testing.T) {
	adapters := BuildCNAdapters(Settings{MockMode: false})
	if len(adapters) != 4 {
		t.Fatalf("adapter count = %d, want 4", len(adapters))
	}
}

func TestEnrichAdapters_ReplacesCNStubs(t *testing.T) {
	t.Setenv("CN_ADAPTER_MOCK_MODE", "true")

	base := []adapter.ModelAdapter{
		&adapter.StubAdapter{AdapterName: "SeedreamAdapter"},
		&adapter.StubAdapter{AdapterName: "TongyiWanxiangAdapter"},
		&adapter.StubAdapter{AdapterName: "JimengAdapter"},
		&adapter.StubAdapter{AdapterName: "SeedanceAdapter"},
		&adapter.StubAdapter{AdapterName: "GptImage2Adapter"},
	}
	enriched := EnrichAdapters(base)

	names := make(map[string]bool, len(enriched))
	for _, a := range enriched {
		names[a.Name()] = true
	}
	for _, want := range []string{"SeedreamAdapter", "TongyiWanxiangAdapter", "JimengAdapter", "SeedanceAdapter", "GptImage2Adapter"} {
		if !names[want] {
			t.Fatalf("missing adapter %s after enrich", want)
		}
	}
}
