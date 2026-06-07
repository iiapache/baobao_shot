package gptimage2

import (
	"fmt"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const (
	outputSizePortrait = "1024x1024"
	outputSizeEdit     = "1024x1024"
)

// editStylePrompt maps play/style ids to GPT Image edit prompts (OS).
var editStylePrompt = map[string]string{
	"ghibli_kid":    "Transform the photo into a Studio Ghibli-style children's illustration with soft lighting; preserve the baby's facial features and expression",
	"photo_restore": "Restore an old photo: remove scratches and noise, natural colorization, improved clarity, keep realistic appearance",
	"cartoon_edit":  "Convert to a warm cartoon illustration suitable for baby growth photos; keep the subject recognizable with soft colors",
	"style_swap":    "Apply the requested art style while keeping the subject consistent; soft tones suitable for baby photos",
}

// genStylePrompt maps play/style ids to GPT Image generation prompts (OS).
var genStylePrompt = map[string]string{
	"gpt_portrait":  "High-quality professional baby portrait photo, soft natural lighting, shallow depth of field, 1024px output",
	"storybook_gen": "Warm children's storybook illustration, hand-drawn texture, bright colors, suitable for baby growth album",
}

// VendorRequest is the translated OpenAI GPT Image payload (via overseas proxy).
type VendorRequest struct {
	ModelID     string
	Prompt      string
	ImageURL    string
	ObjectKey   string
	Style       string
	Capability  model.Capability
	OutputSize  string
}

// TranslateInput maps InvokeRequest to a vendor-ready GPT Image request.
func TranslateInput(req adapter.InvokeRequest, modelID string, imageURL string) (VendorRequest, error) {
	if strings.TrimSpace(req.Input.ObjectKey) == "" && req.Capability == model.CapabilityImageEdit {
		return VendorRequest{}, adapter.NewAdapterError(
			adapter.ErrCodeInvalidInput,
			"",
			"missing input objectKey",
		)
	}

	style := strings.TrimSpace(req.Style)
	var prompt string
	var size string

	switch req.Capability {
	case model.CapabilityImageEdit:
		p, ok := editStylePrompt[style]
		if !ok {
			return VendorRequest{}, adapter.NewAdapterError(
				adapter.ErrCodeUnsupported,
				"",
				fmt.Sprintf("unsupported edit style %q", style),
			)
		}
		prompt = p
		size = outputSizeEdit
	case model.CapabilityImageGen:
		p, ok := genStylePrompt[style]
		if !ok {
			return VendorRequest{}, adapter.NewAdapterError(
				adapter.ErrCodeUnsupported,
				"",
				fmt.Sprintf("unsupported gen style %q", style),
			)
		}
		prompt = p
		size = outputSizePortrait
	default:
		return VendorRequest{}, adapter.NewAdapterError(
			adapter.ErrCodeUnsupported,
			"",
			fmt.Sprintf("capability %s not supported", req.Capability),
		)
	}

	return VendorRequest{
		ModelID:    modelID,
		Prompt:     prompt,
		ImageURL:   imageURL,
		ObjectKey:  req.Input.ObjectKey,
		Style:      style,
		Capability: req.Capability,
		OutputSize: size,
	}, nil
}
