package watermark

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"testing"
)

func tintedPNG(width, height int) []byte {
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.Set(x, y, color.RGBA{R: 180, G: 200, B: 220, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		panic(err)
	}
	return buf.Bytes()
}

func TestApplyImage_PNGExplicitAndImplicit(t *testing.T) {
	src := tintedPNG(320, 240)
	source := SourcePrefix + "SeedreamAdapter"

	out, err := ApplyImage(src, source)
	if err != nil {
		t.Fatalf("ApplyImage() error = %v", err)
	}
	if len(out) <= len(src) {
		t.Fatal("expected watermarked PNG to differ from source")
	}
	if !HasImplicitImageMarker(out, source) {
		t.Fatal("missing implicit XMP/EXIF marker")
	}
	img, _, err := image.Decode(bytes.NewReader(out))
	if err != nil {
		t.Fatalf("decode output: %v", err)
	}
	bounds := img.Bounds()
	// Bottom-right corner should differ after badge overlay.
	if img.At(bounds.Max.X-8, bounds.Max.Y-8) == img.At(bounds.Min.X, bounds.Min.Y) {
		t.Fatal("expected corner pixel change from badge overlay")
	}
}

func TestApplyImage_UnsupportedFormat(t *testing.T) {
	_, err := ApplyImage([]byte("not-image"), SourcePrefix+"x")
	if err == nil {
		t.Fatal("expected error for invalid image")
	}
}

func TestDetectImageFormat(t *testing.T) {
	if DetectImageFormat(MinimalPNG(8, 8)) != "png" {
		t.Fatal("want png")
	}
	jpeg := []byte{0xFF, 0xD8, 0xFF, 0xD9}
	if DetectImageFormat(jpeg) != "jpeg" {
		t.Fatal("want jpeg")
	}
}
