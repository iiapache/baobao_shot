package nanobanana

import (
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestTranslateInput_Success(t *testing.T) {
	req := adapter.InvokeRequest{
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageEdit,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/k.jpg"},
	}
	out, err := TranslateInput(req, "imagen-3.0-capability-001", "https://s3.example.com/k.jpg")
	if err != nil {
		t.Fatalf("TranslateInput() error = %v", err)
	}
	if out.Prompt == "" || out.ImageURL == "" {
		t.Fatalf("unexpected output: %+v", out)
	}
}

func TestTranslateInput_UnsupportedCapability(t *testing.T) {
	_, err := TranslateInput(adapter.InvokeRequest{
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageGen,
	}, "imagen-3.0-capability-001", "https://s3.example.com/k.jpg")
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
		Style:      "unknown_style",
		Capability: model.CapabilityImageEdit,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/k.jpg"},
	}, "imagen-3.0-capability-001", "https://s3.example.com/k.jpg")
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeUnsupported {
		t.Fatalf("code = %v, want MODEL_UNSUPPORTED", ae)
	}
}
