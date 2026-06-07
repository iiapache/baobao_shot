package seedream

import (
	"fmt"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const (
	outputWidth  = 1280
	outputHeight = 720
	defaultScale = 0.55
)

// stylePrompt maps play/style ids to Seedream prompt templates (CN image-gen).
var stylePrompt = map[string]string{
	"ghibli_kid":     "宫崎骏吉卜力风格儿童插画，柔和光影，绘本质感，保留宝宝面部特征",
	"seedream_style": "高质量艺术风格化，柔和色调，适合宝宝成长照片",
	"storybook_gen":  "温馨儿童绘本插画风格，手绘质感，明亮色彩",
}

// VendorRequest is the translated Volcengine Seedream payload.
type VendorRequest struct {
	ReqKey    string
	ModelID   string
	ImageURL  string
	Prompt    string
	Width     int
	Height    int
	Scale     float64
	ObjectKey string
	Style     string
}

// TranslateInput maps InvokeRequest to a vendor-ready Seedream request.
func TranslateInput(req adapter.InvokeRequest, modelID string, imageURL string) (VendorRequest, error) {
	if req.Capability != model.CapabilityImageGen {
		return VendorRequest{}, adapter.NewAdapterError(
			adapter.ErrCodeUnsupported,
			"",
			fmt.Sprintf("capability %s not supported", req.Capability),
		)
	}
	if strings.TrimSpace(req.Input.ObjectKey) == "" {
		return VendorRequest{}, adapter.NewAdapterError(
			adapter.ErrCodeInvalidInput,
			"",
			"missing input objectKey",
		)
	}

	style := strings.TrimSpace(req.Style)
	prompt, ok := stylePrompt[style]
	if !ok {
		return VendorRequest{}, adapter.NewAdapterError(
			adapter.ErrCodeUnsupported,
			"",
			fmt.Sprintf("unsupported style %q", style),
		)
	}

	return VendorRequest{
		ReqKey:    "high_aes",
		ModelID:   modelID,
		ImageURL:  imageURL,
		Prompt:    prompt,
		Width:     outputWidth,
		Height:    outputHeight,
		Scale:     defaultScale,
		ObjectKey: req.Input.ObjectKey,
		Style:     style,
	}, nil
}
