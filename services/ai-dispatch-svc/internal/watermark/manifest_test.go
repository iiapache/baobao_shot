package watermark

import (
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestBuildManifest(t *testing.T) {
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	m := BuildManifest(Input{
		TaskID:     "tsk_1",
		Vendor:     "SeedreamAdapter",
		Model:      "SeedreamAdapter",
		Capability: model.CapabilityImageGen,
		PromptHash: "abc123",
		FilingNo:   "DS-DEV-1",
	}, now)

	if m.Version != ManifestVersion {
		t.Fatalf("version = %q", m.Version)
	}
	if m.TaskID != "tsk_1" || m.FilingNo != "DS-DEV-1" {
		t.Fatalf("manifest = %+v", m)
	}
	if m.Source != SourcePrefix+"SeedreamAdapter" {
		t.Fatalf("source = %q", m.Source)
	}

	raw, err := m.MarshalJSON()
	if err != nil {
		t.Fatalf("MarshalJSON() error = %v", err)
	}
	parsed, err := ParseManifest(raw)
	if err != nil {
		t.Fatalf("ParseManifest() error = %v", err)
	}
	if parsed.TaskID != m.TaskID {
		t.Fatalf("parsed = %+v", parsed)
	}
}

func TestManifestObjectKey(t *testing.T) {
	got := ManifestObjectKey("ai-out/usr_1/task.png")
	want := "ai-out/usr_1/task.png.deepsynth.manifest.json"
	if got != want {
		t.Fatalf("got %q want %q", got, want)
	}
}
