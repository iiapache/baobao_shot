package gptimage2

import (
	"context"
	"fmt"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const adapterName = "GptImage2Adapter"

// Adapter implements ModelAdapter for OpenAI GPT Image 2 (OS).
type Adapter struct {
	cfg    Config
	client Client
}

// NewAdapter creates the OS GptImage2 adapter.
func NewAdapter(cfg Config) *Adapter {
	return &Adapter{cfg: cfg, client: cfg.client()}
}

// Name returns the router / filing adapter identifier.
func (a *Adapter) Name() string { return adapterName }

// Region is always OS for GptImage2.
func (a *Adapter) Region() model.Region { return model.RegionOS }

// Supports reports image-edit and image-gen capabilities.
func (a *Adapter) Supports(capability model.Capability) bool {
	return capability == model.CapabilityImageEdit || capability == model.CapabilityImageGen
}

// Cost returns estimated credits for image plays.
func (a *Adapter) Cost(req adapter.InvokeRequest) int {
	switch {
	case req.Style == "gpt_portrait":
		return 15
	case req.Style == "photo_restore":
		return 10
	default:
		return 8
	}
}

// Invoke translates input, calls GPT Image via overseas proxy, and returns output object keys.
func (a *Adapter) Invoke(ctx context.Context, req adapter.InvokeRequest) (adapter.InvokeOutput, error) {
	if err := ctx.Err(); err != nil {
		return adapter.InvokeOutput{}, NormalizeHTTPStatus(0, err.Error())
	}

	imageURL := ""
	if req.Capability == model.CapabilityImageEdit {
		imageURL = a.cfg.objectURL(req.Input.ObjectKey)
	}

	vendorReq, err := TranslateInput(req, a.cfg.modelID(), imageURL)
	if err != nil {
		return adapter.InvokeOutput{}, err
	}

	var resultURL string
	switch req.Capability {
	case model.CapabilityImageGen:
		resultURL, err = a.client.Generate(ctx, vendorReq)
	case model.CapabilityImageEdit:
		resultURL, err = a.client.Edit(ctx, vendorReq)
	default:
		return adapter.InvokeOutput{}, adapter.NewAdapterError(
			adapter.ErrCodeUnsupported,
			"",
			fmt.Sprintf("capability %s not supported", req.Capability),
		)
	}
	if err != nil {
		return adapter.InvokeOutput{}, err
	}

	outKey := deriveOutputKey(req)
	thumbKey := deriveThumbnailKey(outKey)
	_ = resultURL // persisted by worker after S3 fetch; adapter returns planned keys

	return adapter.InvokeOutput{
		ObjectKey:    outKey,
		ThumbnailKey: thumbKey,
	}, nil
}

func deriveOutputKey(req adapter.InvokeRequest) string {
	if req.Capability == model.CapabilityImageGen {
		return fmt.Sprintf("ai-out/%s_%s.png", req.Style, strings.TrimPrefix(req.Input.ObjectKey, "ai-tmp/"))
	}
	base := strings.TrimPrefix(req.Input.ObjectKey, "ai-tmp/")
	if base == req.Input.ObjectKey {
		base = req.Input.ObjectKey
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
