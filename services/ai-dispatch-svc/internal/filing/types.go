package filing

import "github.com/baobao/ai-dispatch-svc/internal/adapter"

// YAMLFile is the on-disk schema for compliance/algorithm-filing/filings.yaml.
type YAMLFile struct {
	AlgorithmFiling map[string]YAMLEntry `yaml:"algorithm_filing"`
}

// YAMLEntry is one adapter's filing numbers.
type YAMLEntry struct {
	GenAIFilingNo     string `yaml:"gen_ai_filing_no" json:"gen_ai_filing_no"`
	DeepSynthFilingNo string `yaml:"deep_synth_filing_no" json:"deep_synth_filing_no"`
}

// Bindings is adapter name → filing info.
type Bindings map[string]adapter.FilingInfo

// ConfigSvcBindingsJSON is the variant payload for compliance.algorithm_filing_bindings.
type ConfigSvcBindingsJSON map[string]YAMLEntry
