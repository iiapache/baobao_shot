package aliyun

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func newMockAdapter(delay time.Duration) *ContentSecurityAdapter {
	return NewContentSecurityAdapter(Config{MockMode: true, MockDelay: delay})
}

func TestAudit_Pass(t *testing.T) {
	adapter := newMockAdapter(0)
	ctx := context.Background()

	cases := []struct {
		name string
		req  Request
	}{
		{
			name: "text",
			req: Request{
				Kind: "input", Region: "cn", MediaType: "text", Text: "宝宝今天很开心",
			},
		},
		{
			name: "image",
			req: Request{
				Kind: "output", Region: "cn", MediaType: "image", ObjectKey: "ai-out/fam_1/out.jpg",
			},
		},
		{
			name: "video",
			req: Request{
				Kind: "ugc", Region: "cn", MediaType: "video", ObjectKey: "family/fam_1/video.mp4",
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			passed, reasons, err := adapter.Audit(ctx, tc.req)
			if err != nil {
				t.Fatalf("Audit() error = %v", err)
			}
			if !passed {
				t.Fatalf("passed = false, reasons = %+v", reasons)
			}
			if len(reasons) != 0 {
				t.Fatalf("reasons = %+v, want empty", reasons)
			}
		})
	}
}

func TestAudit_Reject(t *testing.T) {
	adapter := newMockAdapter(0)
	ctx := context.Background()

	cases := []struct {
		name    string
		req     Request
		reasons []string
	}{
		{
			name: "text spam",
			req: Request{
				Kind: "ugc", Region: "cn", MediaType: "text", Text: "reject_spam 广告",
			},
			reasons: []string{"antispam"},
		},
		{
			name: "image porn",
			req: Request{
				Kind: "input", Region: "cn", MediaType: "image", ObjectKey: "ai-tmp/reject_porn.jpg",
			},
			reasons: []string{"porn"},
		},
		{
			name: "video generic",
			req: Request{
				Kind: "output", Region: "cn", MediaType: "video", ObjectKey: "ai-out/reject_clip.mp4",
			},
			reasons: []string{"porn", "terrorism"},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			passed, reasons, err := adapter.Audit(ctx, tc.req)
			if err != nil {
				t.Fatalf("Audit() error = %v", err)
			}
			if passed {
				t.Fatal("passed = true, want false")
			}
			if len(reasons) != len(tc.reasons) {
				t.Fatalf("reasons = %+v, want %+v", reasons, tc.reasons)
			}
			for i := range tc.reasons {
				if reasons[i] != tc.reasons[i] {
					t.Fatalf("reasons = %+v, want %+v", reasons, tc.reasons)
				}
			}
		})
	}
}

func TestAudit_Timeout(t *testing.T) {
	adapter := newMockAdapter(200 * time.Millisecond)
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	_, _, err := adapter.Audit(ctx, Request{
		Kind: "input", Region: "cn", MediaType: "text", Text: "hello",
	})
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("error = %v, want context.DeadlineExceeded", err)
	}
}

func TestAudit_NonCNRegionPasses(t *testing.T) {
	adapter := newMockAdapter(0)
	passed, reasons, err := adapter.Audit(context.Background(), Request{
		Kind: "input", Region: "os", MediaType: "text", Text: "reject_spam",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if !passed || len(reasons) != 0 {
		t.Fatalf("non-cn region should bypass cn vendor: passed=%v reasons=%+v", passed, reasons)
	}
}

func TestAudit_HTTPClientPass(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"code": 200,
			"data": []map[string]any{
				{"code": 200, "results": []map[string]any{{"scene": "antispam", "suggestion": "pass"}}},
			},
		})
	}))
	defer srv.Close()

	adapter := NewContentSecurityAdapter(Config{
		MockMode: false,
		Endpoint: srv.URL,
	})
	passed, reasons, err := adapter.Audit(context.Background(), Request{
		Kind: "ugc", Region: "cn", MediaType: "text", Text: "hello",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if !passed || len(reasons) != 0 {
		t.Fatalf("passed=%v reasons=%v", passed, reasons)
	}
}
