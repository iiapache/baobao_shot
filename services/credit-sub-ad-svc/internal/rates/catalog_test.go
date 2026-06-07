package rates

import "testing"

func TestLoadCatalog(t *testing.T) {
	catalog, err := LoadCatalog()
	if err != nil {
		t.Fatal(err)
	}
	if catalog.Version == "" {
		t.Fatal("missing version")
	}
	if len(catalog.Plays) == 0 {
		t.Fatal("expected play rates")
	}
	if len(catalog.RechargePacks) == 0 {
		t.Fatal("expected recharge packs")
	}
}
