package jimeng

import (
	"context"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func newMockAdapter() *Adapter {
	return NewAdapter(Config{MockMode: true, ModelID: "jimeng-v3"})
}

func TestAdapter_Metadata(t *testing.T) {
	a := newMockAdapter()
	if a.Name() != "JimengAdapter" {
		t.Fatalf("name = %s", a.Name())
	}
	if a.Region() != model.RegionCN {
		t.Fatalf("region = %s", a.Region())
	}
	if !a.Supports(model.CapabilityImageEdit) {
		t.Fatal("should support image-edit")
	}
	if a.Supports(model.CapabilityImageGen) {
		t.Fatal("should not support image-gen")
	}
	if a.Cost(adapter.InvokeRequest{Style: "ghibli_kid"}) != 8 {
		t.Fatal("cost should be 8 credits")
	}
	if a.Cost(adapter.InvokeRequest{Style: "photo_restore"}) != 10 {
		t.Fatal("photo_restore cost should be 10 credits")
	}
}

func TestAdapter_Invoke_Success(t *testing.T) {
	a := newMockAdapter()
	out, err := a.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "photo_restore",
		Capability: model.CapabilityImageEdit,
		Region:     model.RegionCN,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/task.heic"},
	})
	if err != nil {
		t.Fatalf("Invoke() error = %v", err)
	}
	if out.ObjectKey != "ai-out/usr_1/task.png" {
		t.Fatalf("objectKey = %q", out.ObjectKey)
	}
	if out.ThumbnailKey != "ai-out/usr_1/task_512.jpg" {
		t.Fatalf("thumbnailKey = %q", out.ThumbnailKey)
	}
}

func TestAdapter_Invoke_ErrorNormalization(t *testing.T) {
	a := newMockAdapter()
	cases := []struct {
		name      string
		objectKey string
		code      adapter.ErrorCode
		retryable bool
	}{
		{"rate limit", "ai-tmp/vendor_rate_limit.jpg", adapter.ErrCodeRateLimited, true},
		{"upstream", "ai-tmp/vendor_upstream.jpg", adapter.ErrCodeUpstream, true},
		{"face", "ai-tmp/vendor_face.jpg", adapter.ErrCodeFaceNotFound, false},
		{"policy", "ai-tmp/vendor_policy.jpg", adapter.ErrCodeContentPolicy, false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := a.Invoke(context.Background(), adapter.InvokeRequest{
				Style:      "style_swap",
				Capability: model.CapabilityImageEdit,
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
