package nanobanana

import (
	"fmt"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// stylePrompt maps play/style ids to Nano Banana image-edit prompts (OS).
var stylePrompt = map[string]string{
	"ghibli_kid":    "Transform the photo into a Studio Ghibli-style children's illustration with soft lighting; preserve the baby's facial features and expression",
	"photo_restore": "Restore an old photo: remove scratches and noise, natural colorization, improved clarity, keep realistic appearance",
	"cartoon_edit":  "Convert to a warm cartoon illustration suitable for baby growth photos; keep the subject recognizable with soft colors",
	"style_swap":    "Apply the requested art style while keeping the subject consistent; soft tones suitable for baby photos",
}

// VendorRequest is the translated Google Imagen / Nano Banana payload (via GCP proxy).
type VendorRequest struct {
	ModelID   string
	Prompt    string
	ImageURL  string
	ObjectKey string
	Style     string
}

// TranslateInput maps InvokeRequest to a vendor-ready Nano Banana request.
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

	return VendorRequest{
		ModelID:   modelID,
		Prompt:    prompt,
		ImageURL:  imageURL,
		ObjectKey: req.Input.ObjectKey,
		Style:     style,
	}, nil
}
