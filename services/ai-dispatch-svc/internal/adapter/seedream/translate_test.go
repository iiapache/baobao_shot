package seedream

import (
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestTranslateInput_Success(t *testing.T) {
	req := adapter.InvokeRequest{
		Style:      "ghibli_kid",
		Capability: model.CapabilityImageGen,
		Region:     model.RegionCN,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/photo.heic"},
	}

	out, err := TranslateInput(req, "seedream-v3", "https://oss.example.com/ai-tmp/usr_1/photo.heic")
	if err != nil {
		t.Fatalf("TranslateInput() error = %v", err)
	}
	if out.Prompt == "" {
		t.Fatal("expected non-empty prompt")
	}
	if out.Width != outputWidth || out.Height != outputHeight {
		t.Fatalf("size = %dx%d, want %dx%d", out.Width, out.Height, outputWidth, outputHeight)
	}
	if out.ReqKey != "high_aes" {
		t.Fatalf("req_key = %q, want high_aes", out.ReqKey)
	}
}

func TestTranslateInput_UnsupportedCapability(t *testing.T) {
	_, err := TranslateInput(adapter.InvokeRequest{
		Style:      "ghibli_kid",
		Capability: model.CapabilityImageEdit,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/x.jpg"},
	}, "seedream-v3", "https://x")
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeUnsupported {
		t.Fatalf("code = %v, want MODEL_UNSUPPORTED", ae)
	}
}

func TestTranslateInput_UnsupportedStyle(t *testing.T) {
	_, err := TranslateInput(adapter.InvokeRequest{
		Style:      "unknown_play",
		Capability: model.CapabilityImageGen,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/x.jpg"},
	}, "seedream-v3", "https://x")
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeUnsupported {
		t.Fatalf("code = %v, want MODEL_UNSUPPORTED", ae)
	}
}
