package seedance

import (
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestTranslateInput_Success5s(t *testing.T) {
	req := adapter.InvokeRequest{
		Style:           "video_walk",
		Capability:      model.CapabilityVideoGen,
		Region:          model.RegionCN,
		DurationSeconds: 5,
		Input:           model.TaskInput{ObjectKey: "ai-tmp/usr_1/photo.heic"},
	}

	out, err := TranslateInput(req, "seedance_i2v_v1", "https://oss.example.com/ai-tmp/usr_1/photo.heic")
	if err != nil {
		t.Fatalf("TranslateInput() error = %v", err)
	}
	if out.Frames != frames5Seconds {
		t.Fatalf("frames = %d, want %d", out.Frames, frames5Seconds)
	}
	if out.Format != outputFormatMP4 || out.Codec != outputCodecH264 {
		t.Fatalf("format/codec = %s/%s, want mp4/h264", out.Format, out.Codec)
	}
}

func TestTranslateInput_Success10s(t *testing.T) {
	req := adapter.InvokeRequest{
		Style:           "video_walk",
		Capability:      model.CapabilityVideoGen,
		DurationSeconds: 10,
		Input:           model.TaskInput{ObjectKey: "ai-tmp/usr_1/photo.heic"},
	}

	out, err := TranslateInput(req, "seedance_i2v_v1", "https://oss.example.com/x")
	if err != nil {
		t.Fatalf("TranslateInput() error = %v", err)
	}
	if out.Frames != frames10Seconds {
		t.Fatalf("frames = %d, want %d", out.Frames, frames10Seconds)
	}
}

func TestTranslateInput_UnsupportedDuration(t *testing.T) {
	_, err := TranslateInput(adapter.InvokeRequest{
		Style:           "video_walk",
		Capability:      model.CapabilityVideoGen,
		DurationSeconds: 30,
		Input:           model.TaskInput{ObjectKey: "ai-tmp/x.jpg"},
	}, "seedance_i2v_v1", "https://x")
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeInvalidInput {
		t.Fatalf("code = %v, want MODEL_INVALID_INPUT", ae)
	}
}

func TestTranslateInput_UnsupportedCapability(t *testing.T) {
	_, err := TranslateInput(adapter.InvokeRequest{
		Style:      "video_walk",
		Capability: model.CapabilityImageGen,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/x.jpg"},
	}, "seedance_i2v_v1", "https://x")
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeUnsupported {
		t.Fatalf("code = %v, want MODEL_UNSUPPORTED", ae)
	}
}

func TestCreditCost(t *testing.T) {
	if CreditCost(5) != 60 {
		t.Fatal("5s cost should be 60")
	}
	if CreditCost(10) != 120 {
		t.Fatal("10s cost should be 120")
	}
}
