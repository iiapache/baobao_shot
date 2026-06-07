package filing

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/configclient"
	"gopkg.in/yaml.v3"
)

const configSvcBindingsKey = "compliance.algorithm_filing_bindings"

// LoadOptions controls filing registry bootstrap.
type LoadOptions struct {
	ConfigPath   string
	Environment  string
	ConfigClient configclient.Client
}

// DevBindings returns placeholder filing numbers for local worker runs.
func DevBindings() Bindings {
	return Bindings{
		"SeedreamAdapter":       {GenAIFilingNo: "网信算备11000000000001号", DeepSynthFilingNo: "网信算备11000000000011号"},
		"TongyiWanxiangAdapter": {GenAIFilingNo: "网信算备11000000000002号", DeepSynthFilingNo: "网信算备11000000000012号"},
		"JimengAdapter":         {GenAIFilingNo: "网信算备11000000000003号", DeepSynthFilingNo: "网信算备11000000000013号"},
		"SeedanceAdapter":       {GenAIFilingNo: "网信算备11000000000004号", DeepSynthFilingNo: "网信算备11000000000014号"},
	}
}

// LoadAtStartup builds the filing registry from YAML, env overrides, and optional config-svc pull.
func LoadAtStartup(ctx context.Context, opts LoadOptions) (*Store, error) {
	bindings, source, err := loadBindings(ctx, opts)
	if err != nil {
		return nil, err
	}
	if len(bindings) == 0 {
		if strings.EqualFold(opts.Environment, "dev") || opts.Environment == "" {
			bindings = DevBindings()
			source = "dev-default"
		} else {
			return nil, fmt.Errorf("no algorithm filing bindings loaded")
		}
	}
	return NewStore(bindings, source), nil
}

func loadBindings(ctx context.Context, opts LoadOptions) (Bindings, string, error) {
	var merged Bindings
	source := "none"

	path := resolveConfigPath(opts.ConfigPath)
	if path != "" {
		fromYAML, err := LoadYAML(path)
		if err != nil {
			return nil, "", err
		}
		merged = fromYAML
		source = "yaml:" + path
	}

	if opts.ConfigClient != nil {
		fromSvc, err := loadFromConfigSvc(ctx, opts.ConfigClient)
		if err != nil {
			return nil, "", err
		}
		if len(fromSvc) > 0 {
			merged = mergeBindings(merged, fromSvc)
			source = "config-svc+" + source
		}
	}

	merged = applyEnvOverrides(merged)
	if len(merged) > 0 && source == "none" {
		source = "env"
	}
	return merged, source, nil
}

// LoadYAML parses a filings YAML file into adapter bindings.
func LoadYAML(path string) (Bindings, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read filings config %q: %w", path, err)
	}
	var doc YAMLFile
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("parse filings config %q: %w", path, err)
	}
	return entriesToBindings(doc.AlgorithmFiling), nil
}

func loadFromConfigSvc(ctx context.Context, client configclient.Client) (Bindings, error) {
	features, err := client.Features(ctx, configclient.Request{Region: "cn", UserID: "ai-dispatch-svc"})
	if err != nil {
		return nil, fmt.Errorf("config-svc filing pull: %w", err)
	}
	result, ok := features[configSvcBindingsKey]
	if !ok || !result.Enabled || strings.TrimSpace(result.Variant) == "" {
		return nil, nil
	}
	var parsed ConfigSvcBindingsJSON
	if err := json.Unmarshal([]byte(result.Variant), &parsed); err != nil {
		return nil, fmt.Errorf("decode %s variant: %w", configSvcBindingsKey, err)
	}
	return entriesToBindings(parsed), nil
}

func entriesToBindings(entries map[string]YAMLEntry) Bindings {
	if len(entries) == 0 {
		return nil
	}
	out := make(Bindings, len(entries))
	for name, entry := range entries {
		out[name] = adapter.FilingInfo{
			GenAIFilingNo:     strings.TrimSpace(entry.GenAIFilingNo),
			DeepSynthFilingNo: strings.TrimSpace(entry.DeepSynthFilingNo),
		}
	}
	return out
}

func mergeBindings(base, overlay Bindings) Bindings {
	if len(base) == 0 {
		out := make(Bindings, len(overlay))
		for k, v := range overlay {
			out[k] = v
		}
		return out
	}
	out := make(Bindings, len(base)+len(overlay))
	for k, v := range base {
		out[k] = v
	}
	for k, v := range overlay {
		out[k] = v
	}
	return out
}

func applyEnvOverrides(bindings Bindings) Bindings {
	adapterNames := []string{
		"SeedreamAdapter",
		"TongyiWanxiangAdapter",
		"JimengAdapter",
		"SeedanceAdapter",
	}
	out := bindings
	if out == nil {
		out = make(Bindings)
	}
	changed := false
	for _, name := range adapterNames {
		genKey := "FILING_" + envAdapterKey(name) + "_GEN_AI"
		deepKey := "FILING_" + envAdapterKey(name) + "_DEEP_SYNTH"
		gen := strings.TrimSpace(os.Getenv(genKey))
		deep := strings.TrimSpace(os.Getenv(deepKey))
		if gen == "" && deep == "" {
			continue
		}
		if !changed {
			out = cloneBindings(out)
			changed = true
		}
		entry := out[name]
		if gen != "" {
			entry.GenAIFilingNo = gen
		}
		if deep != "" {
			entry.DeepSynthFilingNo = deep
		}
		out[name] = entry
	}
	return out
}

func envAdapterKey(adapterName string) string {
	switch adapterName {
	case "SeedreamAdapter":
		return "SEEDREAM"
	case "TongyiWanxiangAdapter":
		return "WANXIANG"
	case "JimengAdapter":
		return "JIMENG"
	case "SeedanceAdapter":
		return "SEEDANCE"
	default:
		return strings.ToUpper(strings.TrimSuffix(adapterName, "Adapter"))
	}
}

func cloneBindings(in Bindings) Bindings {
	out := make(Bindings, len(in))
	for k, v := range in {
		out[k] = v
	}
	return out
}

func resolveConfigPath(explicit string) string {
	if explicit != "" {
		return explicit
	}
	if p := os.Getenv("ALGORITHM_FILING_PATH"); p != "" {
		return p
	}
	for _, candidate := range []string{
		"compliance/algorithm-filing/filings.yaml",
		"../../compliance/algorithm-filing/filings.yaml",
		"../../../compliance/algorithm-filing/filings.yaml",
	} {
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return ""
}
