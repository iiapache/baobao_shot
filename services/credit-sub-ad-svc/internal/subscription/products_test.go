package subscription

import "testing"

func TestListProductsByRegion(t *testing.T) {
	cn := ListProducts("cn")
	if len(cn) != 4 {
		t.Fatalf("cn products = %d, want 4", len(cn))
	}
	if cn[0].PriceCNY == 0 {
		t.Fatal("expected cn price")
	}

	osProducts := ListProducts("os")
	if len(osProducts) != 3 {
		t.Fatalf("os products = %d, want 3", len(osProducts))
	}
	if osProducts[0].PriceCNY != 0 {
		t.Fatalf("os price = %d, want 0", osProducts[0].PriceCNY)
	}
}
