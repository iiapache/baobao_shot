package seedance

import (
	"context"
	"fmt"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const adapterName = "SeedanceAdapter"

// Adapter implements ModelAdapter for Volcengine Seedance image-to-video (CN).
type Adapter struct {
	cfg    Config
	client Client
}

// NewAdapter creates the CN Seedance adapter.
func NewAdapter(cfg Config) *Adapter {
	if cfg.ModelID == "" {
		cfg.ModelID = "seedance_i2v_v1"
	}
	return &Adapter{cfg: cfg, client: cfg.client()}
}

// Name returns the router / filing adapter identifier.
func (a *Adapter) Name() string { return adapterName }

// Region is always CN for Seedance.
func (a *Adapter) Region() model.Region { return model.RegionCN }

// Supports reports video-gen capability only.
func (a *Adapter) Supports(capability model.Capability) bool {
	return capability == model.CapabilityVideoGen
}

// Cost returns estimated credits for 5s / 10s video tiers.
func (a *Adapter) Cost(req adapter.InvokeRequest) int {
	duration := req.DurationSeconds
	if duration == 0 {
		duration = defaultDurationS
	}
	return CreditCost(duration)
}

// Invoke translates input, calls Seedance async API (5min timeout), and returns output keys.
func (a *Adapter) Invoke(ctx context.Context, req adapter.InvokeRequest) (adapter.InvokeOutput, error) {
	if err := ctx.Err(); err != nil {
		return adapter.InvokeOutput{}, NormalizeHTTPStatus(0, err.Error())
	}

	imageURL := a.cfg.objectURL(req.Input.ObjectKey)
	vendorReq, err := TranslateInput(req, a.cfg.ModelID, imageURL)
	if err != nil {
		return adapter.InvokeOutput{}, err
	}

	video, err := a.client.Generate(ctx, vendorReq)
	if err != nil {
		return adapter.InvokeOutput{}, err
	}

	outKey := deriveOutputKey(req.Input.ObjectKey)
	thumbKey := deriveThumbnailKey(outKey)
	_ = video.URL // persisted by worker after OSS fetch; adapter returns planned keys

	return adapter.InvokeOutput{
		ObjectKey:    outKey,
		ThumbnailKey: thumbKey,
	}, nil
}

func deriveOutputKey(inputKey string) string {
	base := strings.TrimPrefix(inputKey, "ai-tmp/")
	if base == inputKey {
		base = inputKey
	}
	return fmt.Sprintf("ai-out/%s.mp4", strings.TrimSuffix(base, extOf(base)))
}

func deriveThumbnailKey(outputKey string) string {
	return strings.TrimSuffix(outputKey, extOf(outputKey)) + "_cover.jpg"
}

func extOf(path string) string {
	if i := strings.LastIndex(path, "."); i >= 0 {
		return path[i:]
	}
	return ""
}
