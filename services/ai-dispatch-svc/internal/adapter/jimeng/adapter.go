package jimeng

import (
	"context"
	"fmt"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const adapterName = "JimengAdapter"

// Adapter implements ModelAdapter for Volcengine Jimeng image editing (CN).
type Adapter struct {
	cfg    Config
	client Client
}

// NewAdapter creates the CN Jimeng adapter.
func NewAdapter(cfg Config) *Adapter {
	if cfg.ModelID == "" {
		cfg.ModelID = defaultModelID
	}
	return &Adapter{cfg: cfg, client: cfg.client()}
}

// Name returns the router / filing adapter identifier.
func (a *Adapter) Name() string { return adapterName }

// Region is always CN for Jimeng.
func (a *Adapter) Region() model.Region { return model.RegionCN }

// Supports reports image-edit capability only.
func (a *Adapter) Supports(capability model.Capability) bool {
	return capability == model.CapabilityImageEdit
}

// Cost returns estimated credits for image-edit plays.
func (a *Adapter) Cost(req adapter.InvokeRequest) int {
	if req.Style == "photo_restore" {
		return 10
	}
	return 8
}

// Invoke translates input, calls Jimeng, and returns output object keys.
func (a *Adapter) Invoke(ctx context.Context, req adapter.InvokeRequest) (adapter.InvokeOutput, error) {
	if err := ctx.Err(); err != nil {
		return adapter.InvokeOutput{}, NormalizeHTTPStatus(0, err.Error())
	}

	imageURL := a.cfg.objectURL(req.Input.ObjectKey)
	vendorReq, err := TranslateInput(req, a.cfg.modelID(), imageURL)
	if err != nil {
		return adapter.InvokeOutput{}, err
	}

	resultURL, err := a.client.Edit(ctx, vendorReq)
	if err != nil {
		return adapter.InvokeOutput{}, err
	}

	outKey := deriveOutputKey(req.Input.ObjectKey)
	thumbKey := deriveThumbnailKey(outKey)
	_ = resultURL // persisted by worker after OSS fetch; adapter returns planned keys

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
	return fmt.Sprintf("ai-out/%s.png", strings.TrimSuffix(base, extOf(base)))
}

func deriveThumbnailKey(outputKey string) string {
	return strings.TrimSuffix(outputKey, extOf(outputKey)) + "_512.jpg"
}

func extOf(path string) string {
	if i := strings.LastIndex(path, "."); i >= 0 {
		return path[i:]
	}
	return ""
}
