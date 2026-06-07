package watermark

import (
	"bytes"
	_ "embed"
	"image"
	"image/draw"
	"image/png"
	"sync"
)

//go:embed assets/badge.png
var badgePNG []byte

var (
	badgeOnce sync.Once
	badgeImg  image.Image
	badgeErr  error
)

func loadBadge() (image.Image, error) {
	badgeOnce.Do(func() {
		badgeImg, badgeErr = png.Decode(bytes.NewReader(badgePNG))
	})
	return badgeImg, badgeErr
}

// badgeTargetSize returns overlay dimensions: short edge * ratio, clamped to compliance range.
func badgeTargetSize(img image.Image) (int, int) {
	bounds := img.Bounds()
	short := bounds.Dx()
	if bounds.Dy() < short {
		short = bounds.Dy()
	}
	// 6% of short edge (within PRD 5–8% band).
	targetW := short * 6 / 100
	if targetW < 48 {
		targetW = 48
	}
	src, err := loadBadge()
	if err != nil {
		return targetW, targetW / 4
	}
	srcBounds := src.Bounds()
	ratio := float64(srcBounds.Dy()) / float64(srcBounds.Dx())
	targetH := int(float64(targetW) * ratio)
	if targetH < 12 {
		targetH = 12
	}
	return targetW, targetH
}

// overlayBadge composites the embedded PNG badge at the bottom-right corner.
func overlayBadge(dst *image.RGBA, src image.Image) error {
	badge, err := loadBadge()
	if err != nil {
		return err
	}
	targetW, targetH := badgeTargetSize(dst)
	scaled := resizeNearest(badge, targetW, targetH)

	margin := dst.Bounds().Dx() / 100
	if margin < 4 {
		margin = 4
	}
	x := dst.Bounds().Dx() - targetW - margin
	y := dst.Bounds().Dy() - targetH - margin
	draw.Draw(dst, image.Rect(x, y, x+targetW, y+targetH), scaled, image.Point{}, draw.Over)
	return nil
}

func resizeNearest(src image.Image, width, height int) *image.RGBA {
	dst := image.NewRGBA(image.Rect(0, 0, width, height))
	srcBounds := src.Bounds()
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			sx := srcBounds.Min.X + x*srcBounds.Dx()/width
			sy := srcBounds.Min.Y + y*srcBounds.Dy()/height
			dst.Set(x, y, src.At(sx, sy))
		}
	}
	return dst
}
