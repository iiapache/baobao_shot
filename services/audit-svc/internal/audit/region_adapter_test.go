package audit

import (
	"context"
	"testing"
)

type trackingVendor struct {
	name  string
	calls []VendorRequest
	pass  bool
}

func (v *trackingVendor) Audit(_ context.Context, req VendorRequest) (bool, []string, error) {
	v.calls = append(v.calls, req)
	if v.pass {
		return true, nil, nil
	}
	return false, []string{v.name + "_violation"}, nil
}

func TestRegionVendorAdapter_RoutesOSWithoutCrossRegionCalls(t *testing.T) {
	ctx := context.Background()
	cn := &trackingVendor{name: "cn", pass: true}
	os := &trackingVendor{name: "os", pass: true}

	adapter := NewRegionVendorAdapter(RegionOS, cn, os)

	passed, reasons, err := adapter.Audit(ctx, VendorRequest{
		Region: "os",
		Text:   "hello",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if !passed || len(reasons) != 0 {
		t.Fatalf("passed = %v reasons = %v, want pass", passed, reasons)
	}
	if len(cn.calls) != 0 {
		t.Fatalf("cn vendor calls = %d, want 0 (no cross-region)", len(cn.calls))
	}
	if len(os.calls) != 1 {
		t.Fatalf("os vendor calls = %d, want 1", len(os.calls))
	}
}

func TestRegionVendorAdapter_RoutesCNWithoutCrossRegionCalls(t *testing.T) {
	ctx := context.Background()
	cn := &trackingVendor{name: "cn", pass: true}
	os := &trackingVendor{name: "os", pass: true}

	adapter := NewRegionVendorAdapter(RegionCN, cn, os)

	passed, _, err := adapter.Audit(ctx, VendorRequest{
		Region: "cn",
		Text:   "你好",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if !passed {
		t.Fatal("expected pass")
	}
	if len(os.calls) != 0 {
		t.Fatalf("os vendor calls = %d, want 0 (no cross-region)", len(os.calls))
	}
	if len(cn.calls) != 1 {
		t.Fatalf("cn vendor calls = %d, want 1", len(cn.calls))
	}
}

func TestRegionVendorAdapter_DeployRegionMismatch(t *testing.T) {
	ctx := context.Background()
	cn := &trackingVendor{name: "cn", pass: true}
	os := &trackingVendor{name: "os", pass: true}

	adapter := NewRegionVendorAdapter(RegionOS, cn, os)

	_, _, err := adapter.Audit(ctx, VendorRequest{
		Region: "cn",
		Text:   "你好",
	})
	if err != ErrRegionMismatch {
		t.Fatalf("error = %v, want ErrRegionMismatch", err)
	}
	if len(cn.calls) != 0 || len(os.calls) != 0 {
		t.Fatalf("expected no vendor calls on mismatch, cn=%d os=%d", len(cn.calls), len(os.calls))
	}
}

func TestRegionVendorAdapter_Reject(t *testing.T) {
	ctx := context.Background()
	adapter := NewRegionVendorAdapter(RegionOS, nil, &trackingVendor{name: "os", pass: false})

	passed, reasons, err := adapter.Audit(ctx, VendorRequest{
		Region: "os",
		Text:   "unsafe",
	})
	if err != nil {
		t.Fatalf("Audit() error = %v", err)
	}
	if passed {
		t.Fatal("expected reject")
	}
	if len(reasons) != 1 || reasons[0] != "os_violation" {
		t.Fatalf("reasons = %v", reasons)
	}
}
