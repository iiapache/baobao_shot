import Foundation
import ImageIO
import UniformTypeIdentifiers

public protocol WidgetThumbnailGenerating: Sendable {
    func generateJPEG(from imageData: Data, size: WidgetThumbnailSize) throws -> Data
}

public struct WidgetThumbnailGenerator: WidgetThumbnailGenerating {
    public static let defaultJPEGQuality: CGFloat = 0.82

    private let jpegQuality: CGFloat

    public init(jpegQuality: CGFloat = Self.defaultJPEGQuality) {
        self.jpegQuality = jpegQuality
    }

    public func generateJPEG(from imageData: Data, size: WidgetThumbnailSize) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw WidgetError.thumbnailGenerationFailed
        }

        let thumbnail = try scale(image: image, maxEdge: size.maxEdgeLength)
        return try encodeJPEG(image: thumbnail, quality: jpegQuality)
    }

    private func scale(image: CGImage, maxEdge: Int) throws -> CGImage {
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
            throw WidgetError.thumbnailGenerationFailed
        }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        )

        guard let scaled = context.makeImage() else {
            throw WidgetError.thumbnailGenerationFailed
        }
        return scaled
    }

    private func encodeJPEG(image: CGImage, quality: CGFloat) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw WidgetError.thumbnailGenerationFailed
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw WidgetError.thumbnailGenerationFailed
        }
        return data as Data
    }
}
