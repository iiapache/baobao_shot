# BabyCameraImageKit

HEIC/JPG 编解码、256/1024 缩略图生成、HEIC 兼容降级（T2.2）。

## 能力

| 组件 | 说明 |
| --- | --- |
| `ImageCodec` | ImageIO 编解码；HEIC 不可用时自动降级 JPEG（`didFallbackToJPEG`） |
| `ThumbnailGenerator` | 等比缩放，最长边 ≤ `ThumbnailSize`（256 / 1024） |
| `ThumbnailSize` | `.small` = 256px，`.medium` = 1024px |

## 用法

```swift
let codec = ImageCodec()
let image = try codec.decode(data: jpegData)
let encoded = try codec.encode(image: image, format: .heic, quality: 0.92)
if encoded.didFallbackToJPEG {
    // 设备不支持 HEIC 编码，已写入 JPEG
}

let thumbs = ThumbnailGenerator(codec: codec)
let small = try thumbs.generate(from: image, size: .small)   // 最长边 256
let mediumData = try thumbs.generateData(from: jpegData, size: .medium, format: .jpeg)
```

## 验收（T2.2）

- 单测：`BabyCameraImageKitTests`（编解码往返、格式互转、HEIC 降级、缩略图 256/1024）
- 互转：往返后尺寸一致；有损格式不保证像素级无损

## 测试

```bash
cd ios/Packages/BabyCameraImageKit
swift test   # 需 Xcode + iOS Simulator SDK
```
