import Foundation

/// 分享前处理结果（T5.15）。
public struct SharePreparedAsset: Sendable, Equatable {
    /// 实际用于分享的媒体文件（图片或视频）。
    public let mediaURL: URL
    /// 视频分享缩略图（微信 / 系统分享预览）；图片为 `nil`。
    public let thumbnailURL: URL?
    public let mediaKind: ShareMediaKind
    public let appliedDeepSynthesisBadge: Bool
    public let appliedBrandWatermark: Bool

    public init(
        mediaURL: URL,
        thumbnailURL: URL?,
        mediaKind: ShareMediaKind,
        appliedDeepSynthesisBadge: Bool,
        appliedBrandWatermark: Bool
    ) {
        self.mediaURL = mediaURL
        self.thumbnailURL = thumbnailURL
        self.mediaKind = mediaKind
        self.appliedDeepSynthesisBadge = appliedDeepSynthesisBadge
        self.appliedBrandWatermark = appliedBrandWatermark
    }
}
