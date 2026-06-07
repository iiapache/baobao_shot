package audit

import (
	"context"
	"testing"

	"github.com/baobao/audit-svc/internal/model"
)

func TestOSVendorAdapter_TextPass(t *testing.T) {
	adapter := NewOSVendorAdapter(DefaultOSStubs())
	ctx := context.Background()

	passed, reasons, err := adapter.Audit(ctx, VendorRequest{
		Kind:   model.AuditKindUGC,
		Region: "os",
		Text:   "family update",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if !passed || len(reasons) != 0 {
		t.Fatalf("passed = %v reasons = %v, want pass", passed, reasons)
	}
}

func TestOSVendorAdapter_TextReject(t *testing.T) {
	adapter := NewOSVendorAdapter(DefaultOSStubs())
	ctx := context.Background()

	passed, reasons, err := adapter.Audit(ctx, VendorRequest{
		Kind:   model.AuditKindUGC,
		Region: "os",
		Text:   "contains audit-reject-openai marker",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if passed {
		t.Fatal("expected reject")
	}
	if len(reasons) != 1 || reasons[0] != "openai_moderation:flagged" {
		t.Fatalf("reasons = %v", reasons)
	}
}

func TestOSVendorAdapter_ImagePass(t *testing.T) {
	adapter := NewOSVendorAdapter(DefaultOSStubs())
	ctx := context.Background()

	passed, reasons, err := adapter.Audit(ctx, VendorRequest{
		Kind:      model.AuditKindInput,
		Region:    "os",
		MediaType: "image",
		ObjectKey: "ai/tmp/input.jpg",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if !passed || len(reasons) != 0 {
		t.Fatalf("passed = %v reasons = %v, want pass", passed, reasons)
	}
}

func TestOSVendorAdapter_ImageRejectRekognition(t *testing.T) {
	adapter := NewOSVendorAdapter(DefaultOSStubs())
	ctx := context.Background()

	passed, reasons, err := adapter.Audit(ctx, VendorRequest{
		Kind:      model.AuditKindOutput,
		Region:    "os",
		MediaType: "image",
		ObjectKey: "ai/tmp/audit-reject-rekognition.jpg",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if passed {
		t.Fatal("expected reject")
	}
	if len(reasons) != 1 || reasons[0] != "aws_rekognition:moderation_failed" {
		t.Fatalf("reasons = %v", reasons)
	}
}

func TestOSVendorAdapter_ImageRejectCloudflare(t *testing.T) {
	adapter := NewOSVendorAdapter(DefaultOSStubs())
	ctx := context.Background()

	passed, reasons, err := adapter.Audit(ctx, VendorRequest{
		Kind:      model.AuditKindOutput,
		Region:    "os",
		MediaType: "image",
		ObjectKey: "ai/tmp/audit-reject-cloudflare.jpg",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if passed {
		t.Fatal("expected reject")
	}
	if len(reasons) != 1 || reasons[0] != "cloudflare_guard:unsafe_content" {
		t.Fatalf("reasons = %v", reasons)
	}
}

func TestOSVendorAdapter_VideoPass(t *testing.T) {
	adapter := NewOSVendorAdapter(DefaultOSStubs())
	ctx := context.Background()

	passed, _, err := adapter.Audit(ctx, VendorRequest{
		Kind:      model.AuditKindOutput,
		Region:    "os",
		MediaType: "video",
		ObjectKey: "ai/tmp/output.mp4",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if !passed {
		t.Fatal("expected pass")
	}
}

func TestOSVendorAdapter_NonOSRegionRejected(t *testing.T) {
	adapter := NewOSVendorAdapter(DefaultOSStubs())
	ctx := context.Background()

	_, _, err := adapter.Audit(ctx, VendorRequest{
		Region: "cn",
		Text:   "hello",
	})
	if err != errOSWrongRegion {
		t.Fatalf("error = %v, want errOSWrongRegion", err)
	}
}

func TestOSVendorAdapter_MockRejectFlags(t *testing.T) {
	stubs := DefaultOSStubs()
	stubs.OpenAI = NewOpenAIModerationAdapter(true)
	adapter := NewOSVendorAdapter(stubs)
	ctx := context.Background()

	passed, reasons, err := adapter.Audit(ctx, VendorRequest{
		Region:    "os",
		MediaType: "text",
		Text:      "clean text",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if passed {
		t.Fatal("expected reject from mock flag")
	}
	if len(reasons) != 1 {
		t.Fatalf("reasons = %v", reasons)
	}
}
