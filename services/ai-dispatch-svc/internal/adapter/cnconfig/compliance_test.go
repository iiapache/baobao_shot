package cnconfig

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/filing"
	"gopkg.in/yaml.v3"
)

// TestFilingsMatchCOMP01 ensures filings.yaml stays aligned with compliance/client-config.yaml (COMP-01).
func TestFilingsMatchCOMP01(t *testing.T) {
	root := filepath.Join("..", "..", "..", "..", "..")
	filingsPath := filepath.Join(root, "compliance", "algorithm-filing", "filings.yaml")
	clientPath := filepath.Join(root, "compliance", "client-config.yaml")

	fromFilings, err := filing.LoadYAML(filingsPath)
	if err != nil {
		t.Fatalf("LoadYAML(filings) error = %v", err)
	}

	raw, err := os.ReadFile(clientPath)
	if err != nil {
		t.Fatalf("read client-config: %v", err)
	}
	var clientDoc struct {
		AlgorithmFiling struct {
			Models map[string]struct {
				GenAIFilingNo     string `yaml:"gen_ai_filing_no"`
				DeepSynthFilingNo string `yaml:"deep_synth_filing_no"`
			} `yaml:"models"`
		} `yaml:"algorithm_filing"`
	}
	if err := yaml.Unmarshal(raw, &clientDoc); err != nil {
		t.Fatalf("parse client-config: %v", err)
	}

	for name, want := range clientDoc.AlgorithmFiling.Models {
		got, ok := fromFilings[name]
		if !ok {
			t.Fatalf("filings.yaml missing adapter %q from client-config", name)
		}
		if got.GenAIFilingNo != want.GenAIFilingNo {
			t.Fatalf("%s gen_ai_filing_no = %q, want %q", name, got.GenAIFilingNo, want.GenAIFilingNo)
		}
		if got.DeepSynthFilingNo != want.DeepSynthFilingNo {
			t.Fatalf("%s deep_synth_filing_no = %q, want %q", name, got.DeepSynthFilingNo, want.DeepSynthFilingNo)
		}
	}
}
