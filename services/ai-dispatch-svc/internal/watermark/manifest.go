package watermark

import (
	"encoding/json"
	"fmt"
	"time"
)

// Manifest is the deepSynth.manifest sidecar payload (design-backend §5.6).
type Manifest struct {
	Version    string    `json:"version"`
	TaskID     string    `json:"taskId"`
	Vendor     string    `json:"vendor"`
	Model      string    `json:"model"`
	Capability string    `json:"capability"`
	PromptHash string    `json:"promptHash"`
	FilingNo   string    `json:"filingNo,omitempty"`
	Source     string    `json:"source"`
	CreatedAt  time.Time `json:"createdAt"`
}

// BuildManifest constructs a manifest for the given generation task.
func BuildManifest(in Input, createdAt time.Time) Manifest {
	return Manifest{
		Version:    ManifestVersion,
		TaskID:     in.TaskID,
		Vendor:     in.Vendor,
		Model:      in.Model,
		Capability: string(in.Capability),
		PromptHash: in.PromptHash,
		FilingNo:   in.FilingNo,
		Source:     SourcePrefix + in.Model,
		CreatedAt:  createdAt.UTC(),
	}
}

// MarshalJSON encodes the manifest with stable field ordering via encoding/json.
func (m Manifest) MarshalJSON() ([]byte, error) {
	type alias Manifest
	return json.Marshal(alias(m))
}

// ManifestObjectKey derives the OSS sidecar key for a primary artifact.
func ManifestObjectKey(objectKey string) string {
	return objectKey + ".deepsynth.manifest.json"
}

// ParseManifest decodes manifest JSON bytes.
func ParseManifest(data []byte) (Manifest, error) {
	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return Manifest{}, fmt.Errorf("parse manifest: %w", err)
	}
	if m.Version == "" {
		return Manifest{}, fmt.Errorf("manifest missing version")
	}
	return m, nil
}
