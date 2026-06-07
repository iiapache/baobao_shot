package watermark

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"
	"image/png"
	"strings"
)

// ApplyImage applies explicit corner badge and implicit XMP/EXIF metadata to image bytes.
func ApplyImage(data []byte, source string) ([]byte, error) {
	img, format, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("decode image: %w", err)
	}

	bounds := img.Bounds()
	rgba := image.NewRGBA(bounds)
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			rgba.Set(x, y, img.At(x, y))
		}
	}
	if err := overlayBadge(rgba, img); err != nil {
		return nil, err
	}

	var encoded bytes.Buffer
	switch strings.ToLower(format) {
	case "jpeg", "jpg":
		if err := jpeg.Encode(&encoded, rgba, &jpeg.Options{Quality: 92}); err != nil {
			return nil, err
		}
		return embedJPEGMetadata(encoded.Bytes(), source)
	default:
		if err := png.Encode(&encoded, rgba); err != nil {
			return nil, err
		}
		return embedPNGMetadata(encoded.Bytes(), source)
	}
}

// MinimalPNG returns a solid-color PNG for tests.
func MinimalPNG(width, height int) []byte {
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.Set(x, y, image.White)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		panic(err)
	}
	return buf.Bytes()
}

// DetectImageFormat reports png or jpeg from magic bytes.
func DetectImageFormat(data []byte) string {
	if len(data) >= 8 && string(data[:8]) == pngSignature {
		return "png"
	}
	if len(data) >= 2 && data[0] == 0xFF && data[1] == 0xD8 {
		return "jpeg"
	}
	return ""
}

// HasImplicitImageMarker reports whether XMP or EXIF carries the AIGC source tag.
func HasImplicitImageMarker(data []byte, source string) bool {
	return bytes.Contains(data, []byte(source)) || bytes.Contains(data, []byte("dc:Source"))
}
