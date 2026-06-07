import BabyCameraImageKit
import BabyCameraWatermark
import CoreGraphics
import Foundation

public enum PostWatermarkPreviewError: Error, Equatable, Sendable {
    case emptySource
    case renderFailed
}

/// 发布编辑器水印预览（联动 WatermarkRenderer，T3.25/T2.16）。
public protocol PostWatermarkPreviewing: Sendable {
    func previewCGImage(
        sourceData: Data,
        isSubscribed: Bool,
        includesDeepSynthesisBadge: Bool
    ) throws -> CGImage
}

public struct PostComposerWatermarkPreview: PostWatermarkPreviewing {
    private let renderer: any WatermarkRendering
    private let codec: any ImageCodecProtocol

    public init(
        renderer: any WatermarkRendering = WatermarkRenderer(),
        codec: any ImageCodecProtocol = ImageCodec()
    ) {
        self.renderer = renderer
        self.codec = codec
    }

    public func previewCGImage(
        sourceData: Data,
        isSubscribed: Bool,
        includesDeepSynthesisBadge: Bool
    ) throws -> CGImage {
        guard !sourceData.isEmpty else {
            throw PostWatermarkPreviewError.emptySource
        }

        let source = try codec.decode(data: sourceData)
        let options: WatermarkRenderOptions = includesDeepSynthesisBadge ? .aiResult : .cameraCapture
        do {
            return try renderer.drawAllWatermarks(
                on: source,
                isSubscribed: isSubscribed,
                options: options
            )
        } catch {
            throw PostWatermarkPreviewError.renderFailed
        }
    }
}
