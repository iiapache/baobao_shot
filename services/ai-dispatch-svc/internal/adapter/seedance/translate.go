package seedance

import (
	"fmt"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const (
	frames5Seconds  = 121
	frames10Seconds = 241

	outputFormatMP4  = "mp4"
	outputCodecH264  = "h264"
	defaultDurationS = 5
)

// stylePrompt maps play/style ids to Seedance image-to-video prompts (CN video-gen).
var stylePrompt = map[string]string{
	"video_walk": "宝宝自然走动，温馨家庭氛围，镜头轻微跟随，画面流畅真实",
}

// VendorRequest is the translated Volcengine Seedance async video payload.
type VendorRequest struct {
	ReqKey    string
	ModelID   string
	ImageURL  string
	Prompt    string
	Frames    int
	Format    string
	Codec     string
	ObjectKey string
	Style     string
	DurationS int
}

// TranslateInput maps InvokeRequest to a vendor-ready Seedance request.
func TranslateInput(req adapter.InvokeRequest, modelID string, imageURL string) (VendorRequest, error) {
	if req.Capability != model.CapabilityVideoGen {
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

	duration := req.DurationSeconds
	if duration == 0 {
		duration = defaultDurationS
	}
	frames, err := durationToFrames(duration)
	if err != nil {
		return VendorRequest{}, err
	}

	return VendorRequest{
		ReqKey:    modelID,
		ModelID:   modelID,
		ImageURL:  imageURL,
		Prompt:    prompt,
		Frames:    frames,
		Format:    outputFormatMP4,
		Codec:     outputCodecH264,
		ObjectKey: req.Input.ObjectKey,
		Style:     style,
		DurationS: duration,
	}, nil
}

func durationToFrames(seconds int) (int, error) {
	switch seconds {
	case 5:
		return frames5Seconds, nil
	case 10:
		return frames10Seconds, nil
	default:
		return 0, adapter.NewAdapterError(
			adapter.ErrCodeInvalidInput,
			"",
			fmt.Sprintf("unsupported duration %ds (allowed: 5, 10)", seconds),
		)
	}
}

// CreditCost returns play credits for a supported duration tier.
func CreditCost(durationSeconds int) int {
	switch durationSeconds {
	case 10:
		return 120
	default:
		return 60
	}
}
