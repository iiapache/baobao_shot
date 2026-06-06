import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 编码结果，含实际写入格式（HEIC 不可用时可能降级为 JPEG）。
public struct EncodedImage: Sendable, Equatable {
    public let data: Data
    public let format: ImageFormat
    /// 请求 HEIC 但因设备不支持而降级为 JPEG 时为 `true`。
    public let didFallbackToJPEG: Bool

    public init(data: Data, format: ImageFormat, didFallbackToJPEG: Bool = false) {
        self.data = data
        self.format = format
        self.didFallbackToJPEG = didFallbackToJPEG
    }
}

/// HEIC/JPG 编解码协议，便于单测注入 mock。
public protocol ImageCodecProtocol: Sendable {
    func isHEICSupported() -> Bool
    func decode(data: Data) throws -> CGImage
    func encode(
        image: CGImage,
        format: ImageFormat,
        quality: CGFloat
    ) throws -> EncodedImage
}

/// 默认 ImageIO 编解码实现。
public struct ImageCodec: ImageCodecProtocol {
    public static let defaultJPEGQuality: CGFloat = 0.92

    public init() {}

    public func isHEICSupported() -> Bool {
        Self.checkHEICSupport()
    }

    public func decode(data: Data) throws -> CGImage {
        guard !data.isEmpty else {
            throw ImageKitError.invalidData
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageKitError.decodeFailed
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageKitError.decodeFailed
        }

        return image
    }

    public func encode(
        image: CGImage,
        format: ImageFormat,
        quality: CGFloat = Self.defaultJPEGQuality
    ) throws -> EncodedImage {
        let clampedQuality = min(max(quality, 0), 1)

        switch format {
        case .jpeg:
            let data = try Self.encodeImage(image, utType: UTType.jpeg.identifier, quality: clampedQuality)
            return EncodedImage(data: data, format: .jpeg)

        case .heic:
            if Self.checkHEICSupport() {
                let data = try Self.encodeImage(image, utType: UTType.heic.identifier, quality: clampedQuality)
                return EncodedImage(data: data, format: .heic)
            }

            let data = try Self.encodeImage(image, utType: UTType.jpeg.identifier, quality: clampedQuality)
            return EncodedImage(data: data, format: .jpeg, didFallbackToJPEG: true)
        }
    }

    // MARK: - Private

    private static func checkHEICSupport() -> Bool {
        let supported = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return supported.contains(UTType.heic.identifier)
            || supported.contains("public.heic")
    }

    private static func encodeImage(
        _ image: CGImage,
        utType: String,
        quality: CGFloat
    ) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            utType as CFString,
            1,
            nil
        ) else {
            throw ImageKitError.encodeFailed
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageKitError.encodeFailed
        }

        return output as Data
    }
}
