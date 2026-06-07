import BabyCameraVideoKit
import Foundation

/// 分享前水印处理入参（T5.15）。
public struct SharePreparationRequest: Sendable, Equatable {
    public let sourceURL: URL
    public let mediaKind: ShareMediaKind
    /// 当前是否已订阅（控制品牌水印）。
    public let isSubscribed: Bool
    /// AI / 深度合成内容须强制角标，不可关闭。
    public let requiresDeepSynthesisBadge: Bool
    /// 视频是否二次压制（默认透传源文件）。
    public let reencodeVideo: Bool
    public let videoExportConfiguration: VideoExportConfiguration

    public init(
        sourceURL: URL,
        mediaKind: ShareMediaKind,
        isSubscribed: Bool,
        requiresDeepSynthesisBadge: Bool,
        reencodeVideo: Bool = false,
        videoExportConfiguration: VideoExportConfiguration = .prdDefault
    ) {
        self.sourceURL = sourceURL
        self.mediaKind = mediaKind
        self.isSubscribed = isSubscribed
        self.requiresDeepSynthesisBadge = requiresDeepSynthesisBadge
        self.reencodeVideo = reencodeVideo
        self.videoExportConfiguration = videoExportConfiguration
    }
}
