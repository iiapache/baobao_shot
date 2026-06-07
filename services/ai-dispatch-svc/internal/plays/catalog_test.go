package plays

import (
	"context"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/configclient"
)

func TestLoadManifest(t *testing.T) {
	m, err := LoadManifest()
	if err != nil {
		t.Fatal(err)
	}
	if m.Version == "" {
		t.Fatal("expected version")
	}
	if len(m.Plays) < 5 {
		t.Fatalf("plays = %d, want >= 5", len(m.Plays))
	}
	if m.TTLSeconds != 300 {
		t.Fatalf("ttlSeconds = %d, want 300", m.TTLSeconds)
	}
}

func TestCatalogRegionFilterCN(t *testing.T) {
	m, err := LoadManifest()
	if err != nil {
		t.Fatal(err)
	}
	catalog := NewCatalog(m, configclient.NewStub(nil))

	resp, err := catalog.List(context.Background(), ListOptions{
		Region: "cn",
		UserID: "usr_cn",
	})
	if err != nil {
		t.Fatal(err)
	}
	if resp.Region != "cn" {
		t.Fatalf("region = %q, want cn", resp.Region)
	}

	ids := playIDs(resp.Plays)
	if contains(ids, "gpt_portrait") {
		t.Fatal("gpt_portrait should not appear for cn region")
	}
	if !contains(ids, "seedream_style") {
		t.Fatal("expected seedream_style for cn")
	}
	if !contains(ids, "ghibli_kid") {
		t.Fatal("expected ghibli_kid for cn")
	}
}

func TestCatalogRegionFilterOS(t *testing.T) {
	m, _ := LoadManifest()
	catalog := NewCatalog(m, configclient.NewStub(nil))

	resp, err := catalog.List(context.Background(), ListOptions{Region: "os", UserID: "usr_os"})
	if err != nil {
		t.Fatal(err)
	}

	ids := playIDs(resp.Plays)
	if !contains(ids, "gpt_portrait") {
		t.Fatal("expected gpt_portrait for os")
	}
	if contains(ids, "seedream_style") {
		t.Fatal("seedream_style should not appear for os region")
	}
}

func TestCatalogGrayRolloutExcludesPlay(t *testing.T) {
	m, _ := LoadManifest()
	stub := configclient.NewStub(nil)
	stub.SetFeature("ai.play.video_walk", false)
	catalog := NewCatalog(m, stub)

	resp, err := catalog.List(context.Background(), ListOptions{Region: "cn", UserID: "usr_gray"})
	if err != nil {
		t.Fatal(err)
	}
	if contains(playIDs(resp.Plays), "video_walk") {
		t.Fatal("video_walk should be hidden when feature flag disabled")
	}
}

func TestCatalogVideoDurationTiers(t *testing.T) {
	m, _ := LoadManifest()
	catalog := NewCatalog(m, configclient.NewStub(nil))

	resp, err := catalog.List(context.Background(), ListOptions{Region: "cn", UserID: "usr_video"})
	if err != nil {
		t.Fatal(err)
	}

	var videoWalk *PlayItem
	for i := range resp.Plays {
		if resp.Plays[i].ID == "video_walk" {
			videoWalk = &resp.Plays[i]
			break
		}
	}
	if videoWalk == nil {
		t.Fatal("video_walk not found")
	}
	if len(videoWalk.DurationTiers) != 2 {
		t.Fatalf("durationTiers = %d, want 2", len(videoWalk.DurationTiers))
	}
	if videoWalk.DurationTiers[0].DurationSeconds != 5 || videoWalk.DurationTiers[0].CreditCost != 60 {
		t.Fatalf("5s tier = %+v", videoWalk.DurationTiers[0])
	}
	if videoWalk.DurationTiers[1].DurationSeconds != 10 || videoWalk.DurationTiers[1].CreditCost != 120 {
		t.Fatalf("10s tier = %+v", videoWalk.DurationTiers[1])
	}
}

func TestCatalogManifestDisabledPlay(t *testing.T) {
	m, _ := LoadManifest()
	for i := range m.Plays {
		if m.Plays[i].ID == "smart_caption" {
			m.Plays[i].Enabled = false
			break
		}
	}
	catalog := NewCatalog(m, configclient.NewStub(nil))

	resp, err := catalog.List(context.Background(), ListOptions{Region: "cn", UserID: "usr_x"})
	if err != nil {
		t.Fatal(err)
	}
	if contains(playIDs(resp.Plays), "smart_caption") {
		t.Fatal("disabled manifest play should be excluded")
	}
}

func playIDs(plays []PlayItem) []string {
	out := make([]string, len(plays))
	for i, p := range plays {
		out[i] = p.ID
	}
	return out
}

func contains(list []string, target string) bool {
	for _, v := range list {
		if v == target {
			return true
		}
	}
	return false
}
