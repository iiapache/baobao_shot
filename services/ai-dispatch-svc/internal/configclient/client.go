package configclient

import "context"

// FeatureResult is a resolved feature flag from config-svc.
type FeatureResult struct {
	Enabled bool   `json:"enabled"`
	Variant string `json:"variant,omitempty"`
}

// Request carries dimensions for feature evaluation.
type Request struct {
	Region     string
	AppVersion string
	UserID     string
}

// Client evaluates feature flags for play gray rollout.
type Client interface {
	Features(ctx context.Context, req Request) (map[string]FeatureResult, error)
}
