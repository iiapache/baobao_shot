package adreward_test

import (
	"testing"

	"github.com/baobao/credit-sub-ad-svc/internal/adreward"
)

func TestComputeHMACSignDeterministic(t *testing.T) {
	first := adreward.ComputeHMACSign("secret", "tx-1", "usr-1")
	second := adreward.ComputeHMACSign("secret", "tx-1", "usr-1")
	if first != second {
		t.Fatalf("signatures differ: %q vs %q", first, second)
	}
}

func TestRegistryVerify(t *testing.T) {
	registry := adreward.NewRegistry("pangle-secret", "gdt-secret")
	sign := adreward.ComputeHMACSign("pangle-secret", "tx", "usr")
	if !registry.Verify(adreward.NetworkPangle, "tx", "usr", sign) {
		t.Fatal("expected valid pangle signature")
	}
	if registry.Verify(adreward.NetworkPangle, "tx", "usr", "bad-sign") {
		t.Fatal("expected invalid pangle signature")
	}
}
