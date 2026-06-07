package watermark

import (
	"context"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestPipeline_ApplyImage(t *testing.T) {
	store := NewMemoryArtifactStore()
	ctx := context.Background()
	objectKey := "ai-out/usr_1/task.png"
	if err := store.Put(ctx, objectKey, MinimalPNG(512, 512), "image/png"); err != nil {
		t.Fatalf("Put() error = %v", err)
	}

	p := NewPipeline(store)
	result, err := p.Apply(ctx, Input{
		TaskID:     "tsk_img",
		Vendor:     "SeedreamAdapter",
		Model:      "SeedreamAdapter",
		Capability: model.CapabilityImageGen,
		PromptHash: "sha",
		FilingNo:   "DS-DEV-1",
		ObjectKey:  objectKey,
	})
	if err != nil {
		t.Fatalf("Apply() error = %v", err)
	}
	if result.DeepSynth.Watermark != WatermarkVersion || result.DeepSynth.Manifest != ManifestVersion {
		t.Fatalf("deepSynth = %+v", result.DeepSynth)
	}

	marked, err := store.Get(ctx, objectKey)
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	if !HasImplicitImageMarker(marked, SourcePrefix+"SeedreamAdapter") {
		t.Fatal("output missing implicit marker")
	}

	manifestRaw, err := store.Get(ctx, result.ManifestKey)
	if err != nil {
		t.Fatalf("manifest Get() error = %v", err)
	}
	manifest, err := ParseManifest(manifestRaw)
	if err != nil {
		t.Fatalf("ParseManifest() error = %v", err)
	}
	if manifest.TaskID != "tsk_img" {
		t.Fatalf("manifest = %+v", manifest)
	}
}

func TestPipeline_ApplyVideo(t *testing.T) {
	store := NewMemoryArtifactStore()
	ctx := context.Background()
	objectKey := "ai-out/usr_1/task.mp4"
	if err := store.Put(ctx, objectKey, MinimalMP4(), "video/mp4"); err != nil {
		t.Fatalf("Put() error = %v", err)
	}

	p := NewPipeline(store)
	result, err := p.Apply(ctx, Input{
		TaskID:     "tsk_vid",
		Vendor:     "SeedanceAdapter",
		Model:      "SeedanceAdapter",
		Capability: model.CapabilityVideoGen,
		PromptHash: "sha",
		FilingNo:   "DS-DEV-4",
		ObjectKey:  objectKey,
	})
	if err != nil {
		t.Fatalf("Apply() error = %v", err)
	}
	if result.ManifestKey == "" {
		t.Fatal("expected manifest key")
	}
	marked, err := store.Get(ctx, objectKey)
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	tags := VideoTags{Producer: "baobao", Model: "SeedanceAdapter", FilingNo: "DS-DEV-4", Source: SourcePrefix + "SeedanceAdapter"}
	if !HasVideoMarker(marked, tags) {
		t.Fatal("video missing udta markers")
	}
}

func TestPipeline_MissingArtifact(t *testing.T) {
	p := NewPipeline(NewMemoryArtifactStore())
	_, err := p.Apply(context.Background(), Input{
		TaskID:     "tsk_x",
		Model:      "SeedreamAdapter",
		Capability: model.CapabilityImageGen,
		ObjectKey:  "missing",
	})
	if err == nil {
		t.Fatal("expected error")
	}
}
