package watermark

import (
	"testing"
)

func TestApplyVideo_InjectUdta(t *testing.T) {
	src := MinimalMP4()
	tags := VideoTags{
		Producer: "baobao",
		Model:    "SeedanceAdapter",
		FilingNo: "DS-DEV-4",
		Source:   SourcePrefix + "SeedanceAdapter",
	}

	out, err := ApplyVideo(src, tags)
	if err != nil {
		t.Fatalf("ApplyVideo() error = %v", err)
	}
	if len(out) <= len(src) {
		t.Fatal("expected udta injection to grow MP4")
	}
	if !HasVideoMarker(out, tags) {
		t.Fatal("missing AIGC udta markers")
	}
	if !HasMP4UdtaMarker(out, tags.Model) {
		t.Fatal("missing model-specific udta marker")
	}
}

func TestApplyVideo_InvalidInput(t *testing.T) {
	_, err := ApplyVideo([]byte("not-mp4"), VideoTags{})
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestUdtaJSONComment(t *testing.T) {
	got := UdtaJSONComment(VideoTags{Producer: "baobao", Model: "m", FilingNo: "f", Source: "s"})
	if got == "" || got[0] != '{' {
		t.Fatalf("comment = %q", got)
	}
}
