package gptimage2

import (
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestTranslateInput_EditSuccess(t *testing.T) {
	req := adapter.InvokeRequest{
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageEdit,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/k.jpg"},
	}
	out, err := TranslateInput(req, "gpt-image-1", "https://s3.example.com/k.jpg")
	if err != nil {
		t.Fatalf("TranslateInput() error = %v", err)
	}
	if out.Prompt == "" || out.OutputSize != outputSizeEdit {
		t.Fatalf("unexpected output: %+v", out)
	}
}

func TestTranslateInput_GenSuccess(t *testing.T) {
	req := adapter.InvokeRequest{
		Style:      "gpt_portrait",
		Capability: model.CapabilityImageGen,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/k.jpg"},
	}
	out, err := TranslateInput(req, "gpt-image-1", "")
	if err != nil {
		t.Fatalf("TranslateInput() error = %v", err)
	}
	if out.Prompt == "" || out.OutputSize != outputSizePortrait {
		t.Fatalf("unexpected output: %+v", out)
	}
}

func TestTranslateInput_UnsupportedCapability(t *testing.T) {
	_, err := TranslateInput(adapter.InvokeRequest{
		Style:      "gpt_portrait",
		Capability: model.CapabilityVideoGen,
	}, "gpt-image-1", "")
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
	}, "gpt-image-1", "https://s3.example.com/k.jpg")
	if err == nil {
		t.Fatal("expected error")
	}
	ae, ok := adapter.AsAdapterError(err)
	if !ok || ae.Code != adapter.ErrCodeUnsupported {
		t.Fatalf("code = %v, want MODEL_UNSUPPORTED", ae)
	}
}
