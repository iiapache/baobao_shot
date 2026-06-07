import BabyCameraImageKit
import CoreGraphics
import Foundation

/// 将 `SharePreparedAsset` 缩略图压缩至微信 OpenSDK 限制（≤32KB、最长边 ≤120px）（T5.13）。
public struct WechatThumbnailAdapter: Sendable {
    public static let defaultMaxBytes = 32 * 1024
    public static let defaultMaxEdgeLength = 120

    private let codec: any ImageCodecProtocol
    private let maxBytes: Int
    private let maxEdgeLength: Int

    public init(
        codec: any ImageCodecProtocol = ImageCodec(),
        maxBytes: Int = Self.defaultMaxBytes,
        maxEdgeLength: Int = Self.defaultMaxEdgeLength
    ) {
        self.codec = codec
        self.maxBytes = maxBytes
        self.maxEdgeLength = maxEdgeLength
    }

    public func makeThumbData(from asset: SharePreparedAsset) throws -> Data {
        let sourceURL: URL
        switch asset.mediaKind {
        case .image:
            sourceURL = asset.mediaURL
        case .video:
            guard let thumbnailURL = asset.thumbnailURL else {
                throw WechatShareError.thumbnailAdaptationFailed
            }
            sourceURL = thumbnailURL
        }

        let sourceData = try Data(contentsOf: sourceURL)
        let sourceImage = try codec.decode(data: sourceData)
        return try compressUnderLimit(scaleImage(sourceImage, maxEdge: maxEdgeLength))
    }

    private func scaleImage(_ image: CGImage, maxEdge: Int) -> CGImage {
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
            return image
        }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        )

        return context.makeImage() ?? image
    }

    private func compressUnderLimit(_ image: CGImage) throws -> Data {
        var edge = maxEdgeLength
        while edge >= 60 {
            var quality: CGFloat = 0.85
            while quality >= 0.25 {
                let encoded = try codec.encode(image: scaleImage(image, maxEdge: edge), format: .jpeg, quality: quality)
                if encoded.data.count <= maxBytes {
                    return encoded.data
                }
                quality -= 0.1
            }
            edge -= 20
        }

        throw WechatShareError.thumbnailAdaptationFailed
    }
}
