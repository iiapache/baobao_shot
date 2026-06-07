package tongyi

import (
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestTranslateInput_Success(t *testing.T) {
	req := adapter.InvokeRequest{
		Style:      "style_swap",
		Capability: model.CapabilityImageEdit,
		Region:     model.RegionCN,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/photo.heic"},
	}

	out, err := TranslateInput(req, "wan2.5-i2i-preview", "https://oss.example.com/ai-tmp/usr_1/photo.heic")
	if err != nil {
		t.Fatalf("TranslateInput() error = %v", err)
	}
	if out.Prompt == "" {
		t.Fatal("expected non-empty prompt")
	}
	if out.Function != "" {
		t.Fatalf("function = %q, want empty for wan2.5", out.Function)
	}
	if out.ModelID != "wan2.5-i2i-preview" {
		t.Fatalf("model = %q", out.ModelID)
	}
}

func TestTranslateInput_Wanx21Function(t *testing.T) {
	req := adapter.InvokeRequest{
		Style:      "ghibli_kid",
		Capability: model.CapabilityImageEdit,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/x.jpg"},
	}

	out, err := TranslateInput(req, "wanx2.1-imageedit", "https://x")
	if err != nil {
		t.Fatalf("TranslateInput() error = %v", err)
	}
	if out.Function != "stylization_all" {
		t.Fatalf("function = %q, want stylization_all", out.Function)
	}
}

func TestTranslateInput_UnsupportedCapability(t *testing.T) {
	_, err := TranslateInput(adapter.InvokeRequest{
		Style:      "style_swap",
		Capability: model.CapabilityImageGen,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/x.jpg"},
	}, "wan2.5-i2i-preview", "https://x")
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
		Capability: model.CapabilityImageEdit,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/x.jpg"},
	}, "wan2.5-i2i-preview", "https://x")
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeUnsupported {
		t.Fatalf("code = %v, want MODEL_UNSUPPORTED", ae)
	}
}
