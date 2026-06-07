package plays

import (
	_ "embed"
	"encoding/json"
	"fmt"
)

//go:embed plays.manifest.json
var manifestJSON []byte

// DurationTier is a video play length option with its credit cost.
type DurationTier struct {
	DurationSeconds int `json:"durationSeconds"`
	CreditCost      int `json:"creditCost"`
}

// ManifestPlay is a raw play entry from the embedded manifest.
type ManifestPlay struct {
	ID             string         `json:"id"`
	Name           string         `json:"name"`
	Description    string         `json:"description,omitempty"`
	Kind           string         `json:"kind"`
	Regions        []string       `json:"regions,omitempty"`
	CreditCost     int            `json:"creditCost,omitempty"`
	DurationTiers  []DurationTier `json:"durationTiers,omitempty"`
	Enabled        bool           `json:"enabled"`
	FeatureFlagKey string         `json:"featureFlagKey,omitempty"`
}

// Manifest is the full plays catalog loaded from JSON.
type Manifest struct {
	Version    string         `json:"version"`
	TTLSeconds int            `json:"ttlSeconds"`
	Plays      []ManifestPlay `json:"plays"`
}

// LoadManifest parses the embedded plays manifest.
func LoadManifest() (Manifest, error) {
	var m Manifest
	if err := json.Unmarshal(manifestJSON, &m); err != nil {
		return Manifest{}, fmt.Errorf("parse plays manifest: %w", err)
	}
	if m.Version == "" {
		return Manifest{}, fmt.Errorf("plays manifest missing version")
	}
	if m.TTLSeconds <= 0 {
		m.TTLSeconds = 300
	}
	return m, nil
}
