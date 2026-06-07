package configclient

import (
	"context"
	"strings"
)

// Stub is an in-memory config-svc stub for tests and local dev.
type Stub struct {
	features map[string]FeatureResult
}

// NewStub returns a stub with optional predefined feature results.
func NewStub(features map[string]FeatureResult) *Stub {
	if features == nil {
		features = defaultPlayFeatures()
	}
	return &Stub{features: features}
}

func defaultPlayFeatures() map[string]FeatureResult {
	keys := []string{
		"compliance.os_training_opt_out",
		"ai.play.ghibli_kid",
		"ai.play.gpt_portrait",
		"ai.play.seedream_style",
		"ai.play.photo_restore",
		"ai.play.video_walk",
		"ai.play.year_review_regen",
		"ai.play.smart_caption",
	}
	out := make(map[string]FeatureResult, len(keys))
	for _, k := range keys {
		out[k] = FeatureResult{Enabled: true}
	}
	return out
}

// Features returns the stub feature map (ignores request dimensions except region overrides).
func (s *Stub) Features(_ context.Context, req Request) (map[string]FeatureResult, error) {
	out := make(map[string]FeatureResult, len(s.features))
	for k, v := range s.features {
		out[k] = v
	}
	// gpt_portrait is OS-only; stub mirrors config-svc region behavior.
	if strings.ToLower(req.Region) == "cn" {
		if r, ok := out["ai.play.gpt_portrait"]; ok {
			r.Enabled = false
			out["ai.play.gpt_portrait"] = r
		}
	}
	return out, nil
}

// SetFeature updates a stub flag (for tests).
func (s *Stub) SetFeature(key string, enabled bool) {
	s.features[key] = FeatureResult{Enabled: enabled}
}
