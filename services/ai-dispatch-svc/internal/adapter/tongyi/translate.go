package tongyi

import (
	"fmt"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// stylePrompt maps play/style ids to Wanxiang image-edit prompts (CN).
var stylePrompt = map[string]string{
	"ghibli_kid":    "将照片转换为宫崎骏吉卜力风格儿童插画，柔和光影，保留宝宝面部特征与神态",
	"photo_restore": "修复老旧照片，去除划痕与噪点，自然上色，提升清晰度，保持人物真实感",
	"style_swap":    "替换为指定艺术风格，保持主体一致，柔和色调，适合宝宝成长照片",
}

// VendorRequest is the translated DashScope Wanxiang payload.
type VendorRequest struct {
	ModelID   string
	Prompt    string
	ImageURL  string
	Function  string // wanx2.1-imageedit function; empty for wan2.5-i2i
	ObjectKey string
	Style     string
}

// TranslateInput maps InvokeRequest to a vendor-ready Wanxiang request.
func TranslateInput(req adapter.InvokeRequest, modelID string, imageURL string) (VendorRequest, error) {
	if req.Capability != model.CapabilityImageEdit {
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

	fn := ""
	if strings.Contains(modelID, "imageedit") {
		fn = "stylization_all"
	}

	return VendorRequest{
		ModelID:   modelID,
		Prompt:    prompt,
		ImageURL:  imageURL,
		Function:  fn,
		ObjectKey: req.Input.ObjectKey,
		Style:     style,
	}, nil
}
