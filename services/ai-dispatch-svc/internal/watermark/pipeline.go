package watermark

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// Input describes one artifact watermarking request.
type Input struct {
	TaskID       string
	Vendor       string
	Model        string
	Capability   model.Capability
	PromptHash   string
	FilingNo     string
	ObjectKey    string
	ThumbnailKey string
}

// Result holds watermarked artifact keys and deepSynth metadata.
type Result struct {
	ObjectKey    string
	ThumbnailKey string
	ManifestKey  string
	ManifestJSON []byte
	DeepSynth    model.DeepSynthMetadata
}

// Pipeline applies deep-synthesis explicit + implicit markers to generated artifacts.
type Pipeline struct {
	store ArtifactStore
}

// NewPipeline creates a watermark pipeline backed by the given artifact store.
func NewPipeline(store ArtifactStore) *Pipeline {
	if store == nil {
		store = NewMemoryArtifactStore()
	}
	return &Pipeline{store: store}
}

// Apply fetches the model output, writes markers, persists sidecar manifest, and returns metadata.
func (p *Pipeline) Apply(ctx context.Context, in Input) (Result, error) {
	if strings.TrimSpace(in.ObjectKey) == "" {
		return Result{}, fmt.Errorf("object key required")
	}
	raw, err := p.store.Get(ctx, in.ObjectKey)
	if err != nil {
		return Result{}, err
	}

	source := SourcePrefix + in.Model
	createdAt := time.Now().UTC()
	manifest := BuildManifest(in, createdAt)
	manifestJSON, err := manifest.MarshalJSON()
	if err != nil {
		return Result{}, err
	}

	var (
		marked   []byte
		mimeType string
	)
	switch {
	case in.Capability == model.CapabilityVideoGen || isMP4(raw):
		tags := VideoTags{
			Producer: "baobao",
			Model:    in.Model,
			FilingNo: in.FilingNo,
			Source:   source,
		}
		marked, err = ApplyVideo(raw, tags)
		mimeType = "video/mp4"
	case DetectImageFormat(raw) != "":
		marked, err = ApplyImage(raw, source)
		mimeType = imageMIME(raw)
	default:
		return Result{}, fmt.Errorf("unsupported artifact format for %q", in.ObjectKey)
	}
	if err != nil {
		return Result{}, err
	}

	if err := p.store.Put(ctx, in.ObjectKey, marked, mimeType); err != nil {
		return Result{}, err
	}

	thumbKey := in.ThumbnailKey
	if thumbKey != "" {
		if thumbRaw, thumbErr := p.store.Get(ctx, thumbKey); thumbErr == nil && DetectImageFormat(thumbRaw) != "" {
			thumbMarked, markErr := ApplyImage(thumbRaw, source)
			if markErr == nil {
				if putErr := p.store.Put(ctx, thumbKey, thumbMarked, imageMIME(thumbRaw)); putErr == nil {
					thumbKey = in.ThumbnailKey
				}
			}
		}
	}

	manifestKey := ManifestObjectKey(in.ObjectKey)
	if err := p.store.Put(ctx, manifestKey, manifestJSON, "application/json"); err != nil {
		return Result{}, err
	}

	return Result{
		ObjectKey:    in.ObjectKey,
		ThumbnailKey: thumbKey,
		ManifestKey:  manifestKey,
		ManifestJSON: manifestJSON,
		DeepSynth: model.DeepSynthMetadata{
			Watermark: WatermarkVersion,
			Manifest:  ManifestVersion,
		},
	}, nil
}

func imageMIME(data []byte) string {
	if DetectImageFormat(data) == "jpeg" {
		return "image/jpeg"
	}
	return "image/png"
}
