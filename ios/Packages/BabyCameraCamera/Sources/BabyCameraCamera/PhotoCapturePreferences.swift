import BabyCameraImageKit
import Foundation

/// 拍摄输出偏好（PRD §4.3.1：默认 HEIC，设置可改 JPG；质量 0.92）。
public struct PhotoCapturePreferences: Equatable, Sendable, Codable {
    public var preferredFormat: ImageFormat
    public var jpegQuality: CGFloat

    public static let `default` = PhotoCapturePreferences(
        preferredFormat: .heic,
        jpegQuality: ImageCodec.defaultJPEGQuality
    )

    public init(
        preferredFormat: ImageFormat = .heic,
        jpegQuality: CGFloat = ImageCodec.defaultJPEGQuality
    ) {
        self.preferredFormat = preferredFormat
        self.jpegQuality = min(max(jpegQuality, 0), 1)
    }
}
