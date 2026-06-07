package watermark

const (
	// WatermarkVersion is the explicit corner-badge schema version (design-api deepSynth.watermark).
	WatermarkVersion = "v1"
	// ManifestVersion is the deepSynth.manifest JSON schema version.
	ManifestVersion = "c2pa-v1"
	// BadgeLabel is the mandatory visible deep-synthesis label (PRD §6.2).
	BadgeLabel = "AI 生成 · 深度合成"
	// SourcePrefix is written to XMP/EXIF dc:Source and manifest.source.
	SourcePrefix = "AIGC:baobao/"
)
