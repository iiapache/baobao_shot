import Foundation
import ImageIO

/// 缩略图生成协议。
public protocol ThumbnailGenerating: Sendable {
    func generate(from image: CGImage, size: ThumbnailSize) throws -> CGImage
    func generateData(
        from data: Data,
        size: ThumbnailSize,
        format: ImageFormat,
        quality: CGFloat
    ) throws -> EncodedImage
}

/// 等比缩放缩略图生成器（最长边不超过 `ThumbnailSize`）。
public struct ThumbnailGenerator: ThumbnailGenerating {
    private let codec: any ImageCodecProtocol

    public init(codec: any ImageCodecProtocol = ImageCodec()) {
        self.codec = codec
    }

    public func generate(from image: CGImage, size: ThumbnailSize) throws -> CGImage {
        let maxEdge = size.maxEdgeLength
        let width = image.width
        let height = image.height
        let longestEdge = max(width, height)

        guard longestEdge > maxEdge else {
            return image
        }

        let scale = CGFloat(maxEdge) / CGFloat(longestEdge)
        let targetWidth = max(1, Int((CGFloat(width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(height) * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageKitError.thumbnailFailed
        }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        )

        guard let thumbnail = context.makeImage() else {
            throw ImageKitError.thumbnailFailed
        }

        return thumbnail
    }

    public func generateData(
        from data: Data,
        size: ThumbnailSize,
        format: ImageFormat = .jpeg,
        quality: CGFloat = ImageCodec.defaultJPEGQuality
    ) throws -> EncodedImage {
        let source = try codec.decode(data: data)
        let thumbnail = try generate(from: source, size: size)
        return try codec.encode(image: thumbnail, format: format, quality: quality)
    }
}
