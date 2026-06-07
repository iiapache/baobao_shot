package gptimage2

import (
	"context"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func newMockAdapter() *Adapter {
	return NewAdapter(Config{MockMode: true, ModelID: "gpt-image-1", NoTrainingOptOut: true})
}

func TestAdapter_Metadata(t *testing.T) {
	a := newMockAdapter()
	if a.Name() != "GptImage2Adapter" {
		t.Fatalf("name = %s", a.Name())
	}
	if a.Region() != model.RegionOS {
		t.Fatalf("region = %s", a.Region())
	}
	if !a.Supports(model.CapabilityImageEdit) {
		t.Fatal("should support image-edit")
	}
	if !a.Supports(model.CapabilityImageGen) {
		t.Fatal("should support image-gen")
	}
	if a.Cost(adapter.InvokeRequest{Style: "gpt_portrait"}) != 15 {
		t.Fatal("gpt_portrait cost should be 15 credits")
	}
	if a.Cost(adapter.InvokeRequest{Style: "ghibli_kid"}) != 8 {
		t.Fatal("cost should be 8 credits")
	}
}

func TestAdapter_Invoke_EditSuccess(t *testing.T) {
	a := newMockAdapter()
	out, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageEdit,
		Region:     model.RegionOS,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/task.heic"},
	})
	if err != nil {
		t.Fatalf("Invoke() error = %v", err)
	}
	if out.ObjectKey != "ai-out/usr_1/task.png" {
		t.Fatalf("objectKey = %q", out.ObjectKey)
	}
}

func TestAdapter_Invoke_GenSuccess(t *testing.T) {
	a := newMockAdapter()
	out, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "gpt_portrait",
		Capability: model.CapabilityImageGen,
		Region:     model.RegionOS,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/ref.jpg"},
	})
	if err != nil {
		t.Fatalf("Invoke() error = %v", err)
	}
	if out.ObjectKey != "ai-out/gpt_portrait_usr_1/ref.jpg.png" {
		t.Fatalf("objectKey = %q", out.ObjectKey)
	}
}

func TestAdapter_Invoke_ErrorNormalization(t *testing.T) {
	a := newMockAdapter()
	cases := []struct {
		name       string
		capability model.Capability
		objectKey  string
		code       adapter.ErrorCode
		retryable  bool
	}{
		{"edit rate limit", model.CapabilityImageEdit, "ai-tmp/vendor_rate_limit.jpg", adapter.ErrCodeRateLimited, true},
		{"gen upstream", model.CapabilityImageGen, "ai-tmp/vendor_upstream.jpg", adapter.ErrCodeUpstream, true},
		{"edit face", model.CapabilityImageEdit, "ai-tmp/vendor_face.jpg", adapter.ErrCodeFaceNotFound, false},
		{"gen policy", model.CapabilityImageGen, "ai-tmp/vendor_policy.jpg", adapter.ErrCodeContentPolicy, false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			style := "ghibli_kid"
			if tc.capability == model.CapabilityImageGen {
				style = "storybook_gen"
			}
			_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
				Style:      style,
				Capability: tc.capability,
				Input:      model.TaskInput{ObjectKey: tc.objectKey},
			})
			if err == nil {
				t.Fatal("expected error")
			}
			ae, ok := adapter.AsAdapterError(err)
			if !ok {
				t.Fatalf("not AdapterError: %v", err)
			}
			if ae.Code != tc.code {
				t.Fatalf("code = %s, want %s", ae.Code, tc.code)
			}
			if adapter.IsRetryable(err) != tc.retryable {
				t.Fatalf("retryable = %v, want %v", adapter.IsRetryable(err), tc.retryable)
			}
		})
	}
}
