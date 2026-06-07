import BabyCameraImageKit
import Foundation

/// 烧入水印请求：PhotoOut 落盘完成后、由 `PhotoCapturePipeline` 在设置开启时调用。
public struct CameraWatermarkRequest: Equatable, Sendable {
    public let sourceFileURL: URL
    public let overlayInfo: CameraOverlayInfo
    public let format: ImageFormat

    public init(sourceFileURL: URL, overlayInfo: CameraOverlayInfo, format: ImageFormat) {
        self.sourceFileURL = sourceFileURL
        self.overlayInfo = overlayInfo
        self.format = format
    }
}

/// 水印合成 hook；T2.16 Watermark Renderer 接入此签名，T2.8 仅定义契约与调用点。
public typealias CameraWatermarkHook = @Sendable (CameraWatermarkRequest) async throws -> URL

/// 默认 no-op：返回原文件 URL，便于单测与未接入 Watermark 模块时的占位。
public enum CameraWatermarkHooks {
    public static let noOp: CameraWatermarkHook = { request in
        request.sourceFileURL
    }
}
