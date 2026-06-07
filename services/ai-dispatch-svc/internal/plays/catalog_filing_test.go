package plays

import (
	"context"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/configclient"
	"github.com/baobao/ai-dispatch-svc/internal/filing"
)

func TestCatalogFilingFilterCN(t *testing.T) {
	m, err := LoadManifest()
	if err != nil {
		t.Fatal(err)
	}
	store := filing.NewStore(filing.Bindings{
		"SeedreamAdapter":       {},
		"TongyiWanxiangAdapter": {},
		"JimengAdapter":         {},
		"SeedanceAdapter":       {},
	}, "test")
	catalog := NewCatalogWithFilings(m, configclient.NewStub(nil), store)

	resp, err := catalog.List(context.Background(), ListOptions{Region: "cn", UserID: "usr_filing"})
	if err != nil {
		t.Fatal(err)
	}
	ids := playIDs(resp.Plays)
	for _, blocked := range []string{"ghibli_kid", "seedream_style", "photo_restore", "video_walk"} {
		if contains(ids, blocked) {
			t.Fatalf("%s should be hidden when CN filings missing", blocked)
		}
	}
	if !contains(ids, "smart_caption") {
		t.Fatal("text play smart_caption should remain available")
	}
}

func TestCatalogFilingOSUnaffected(t *testing.T) {
	m, _ := LoadManifest()
	store := filing.NewStore(filing.Bindings{}, "test")
	catalog := NewCatalogWithFilings(m, configclient.NewStub(nil), store)

	resp, err := catalog.List(context.Background(), ListOptions{Region: "os", UserID: "usr_os"})
	if err != nil {
		t.Fatal(err)
	}
	if len(resp.Plays) == 0 {
		t.Fatal("expected OS plays")
	}
}

func TestCatalogFilingWithValidCNBindings(t *testing.T) {
	m, _ := LoadManifest()
	store := filing.NewStore(filing.DevBindings(), "test")
	catalog := NewCatalogWithFilings(m, configclient.NewStub(nil), store)

	resp, err := catalog.List(context.Background(), ListOptions{Region: "cn", UserID: "usr_ok"})
	if err != nil {
		t.Fatal(err)
	}
	if !contains(playIDs(resp.Plays), "seedream_style") {
		t.Fatal("seedream_style should appear with valid filings")
	}
}
