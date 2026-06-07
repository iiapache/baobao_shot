import BabyCameraImageKit
import Foundation

/// 单次拍摄落盘结果（PhotoOut → ImageKit → 文件系统）。
public struct PhotoOut: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let fileURL: URL
    public let format: ImageFormat
    public let livePhotoMovieURL: URL?
    public let capturedAt: Date
    /// 从发起拍摄到文件写入完成的耗时（秒）。
    public let captureLatency: TimeInterval
    /// 请求 HEIC 但因设备不支持而降级为 JPEG。
    public let didFallbackToJPEG: Bool

    public init(
        id: UUID = UUID(),
        fileURL: URL,
        format: ImageFormat,
        livePhotoMovieURL: URL? = nil,
        capturedAt: Date = Date(),
        captureLatency: TimeInterval,
        didFallbackToJPEG: Bool = false
    ) {
        self.id = id
        self.fileURL = fileURL
        self.format = format
        self.livePhotoMovieURL = livePhotoMovieURL
        self.capturedAt = capturedAt
        self.captureLatency = captureLatency
        self.didFallbackToJPEG = didFallbackToJPEG
    }
}
