package filing

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/configclient"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestLoadYAML(t *testing.T) {
	path := filepath.Join("..", "..", "..", "..", "compliance", "algorithm-filing", "filings.yaml")
	bindings, err := LoadYAML(path)
	if err != nil {
		t.Fatalf("LoadYAML() error = %v", err)
	}
	info := bindings["SeedreamAdapter"]
	if !info.IsValid(model.RegionCN) {
		t.Fatalf("SeedreamAdapter filing invalid: %+v", info)
	}
}

func TestLoadEnvOverrides(t *testing.T) {
	t.Setenv("FILING_SEEDREAM_GEN_AI", "GAI-ENV-1")
	t.Setenv("FILING_SEEDREAM_DEEP_SYNTH", "DS-ENV-1")

	bindings := applyEnvOverrides(Bindings{
		"SeedreamAdapter": {GenAIFilingNo: "old-gen", DeepSynthFilingNo: "old-deep"},
	})
	info := bindings["SeedreamAdapter"]
	if info.GenAIFilingNo != "GAI-ENV-1" || info.DeepSynthFilingNo != "DS-ENV-1" {
		t.Fatalf("env override = %+v", info)
	}
}

func TestDevBindingsValid(t *testing.T) {
	for name, info := range DevBindings() {
		if !info.IsValid(model.RegionCN) {
			t.Fatalf("%s dev filing invalid: %+v", name, info)
		}
	}
}

func TestMaskFilingNo(t *testing.T) {
	if got := MaskFilingNo("GAI-DEV-1234"); got != "********1234" {
		t.Fatalf("MaskFilingNo() = %q", got)
	}
	if got := MaskFilingNo(""); got != "(empty)" {
		t.Fatalf("empty mask = %q", got)
	}
}

func TestStore_PlayRoutableInCN_withFiling(t *testing.T) {
	store := NewStore(DevBindings(), "test")
	if !store.PlayRoutableInCN("seedream_style") {
		t.Fatal("seedream_style should be routable with dev filings")
	}
}

func TestStore_PlayRoutableInCN_withoutFiling(t *testing.T) {
	store := NewStore(Bindings{
		"SeedreamAdapter": {},
	}, "test")
	if store.PlayRoutableInCN("seedream_style") {
		t.Fatal("seedream_style should be hidden without filing")
	}
}

func TestLoadFromConfigSvcJSON(t *testing.T) {
	stub := configclient.NewStub(map[string]configclient.FeatureResult{
		"compliance.algorithm_filing_bindings": {
			Enabled: true,
			Variant: `{"SeedreamAdapter":{"gen_ai_filing_no":"GAI-SVC-1","deep_synth_filing_no":"DS-SVC-1"}}`,
		},
	})
	store, err := LoadAtStartup(context.Background(), LoadOptions{
		Environment:  "prod",
		ConfigClient: stub,
	})
	if err != nil {
		t.Fatalf("LoadAtStartup() error = %v", err)
	}
	info, ok := store.Lookup("SeedreamAdapter")
	if !ok || info.GenAIFilingNo != "GAI-SVC-1" {
		t.Fatalf("config-svc binding = %+v, ok=%v", info, ok)
	}
}

func TestLoadAtStartupUsesYAMLWhenPresent(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "filings.yaml")
	if err := os.WriteFile(path, []byte(`algorithm_filing:
  SeedreamAdapter:
    gen_ai_filing_no: GAI-TMP-1
    deep_synth_filing_no: DS-TMP-1
`), 0o600); err != nil {
		t.Fatal(err)
	}
	store, err := LoadAtStartup(context.Background(), LoadOptions{
		ConfigPath:  path,
		Environment: "prod",
	})
	if err != nil {
		t.Fatal(err)
	}
	info, _ := store.Lookup("SeedreamAdapter")
	if info.GenAIFilingNo != "GAI-TMP-1" {
		t.Fatalf("yaml binding = %+v", info)
	}
}
