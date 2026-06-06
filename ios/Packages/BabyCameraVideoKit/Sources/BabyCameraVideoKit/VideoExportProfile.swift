import AVFoundation
import Foundation

/// 视频导出档位，与 PRD §4.6 对齐。
public enum VideoExportProfile: String, Sendable, Equatable, CaseIterable {
    /// 源文件已合规时直接透传（不重编码）。
    case passthrough
    /// PRD V1 默认：720p MP4/H.264。
    case full720p
    /// PRD V1.1：1080p MP4/H.264。
    case full1080p
    /// 家庭圈预览版：720p 较低码率二次压制。
    case familyPreview

    /// 对应 AVAssetExportSession 预设名。
    var exportPresetName: String {
        switch self {
        case .passthrough:
            return AVAssetExportPresetPassthrough
        case .full720p, .familyPreview:
            return AVAssetExportPreset1280x720
        case .full1080p:
            return AVAssetExportPreset1920x1080
        }
    }

    /// 目标最长边（像素），用于验收与日志。
    public var targetMaxEdge: Int {
        switch self {
        case .passthrough:
            return 0
        case .full720p, .familyPreview:
            return 720
        case .full1080p:
            return 1080
        }
    }
}

/// 视频导出配置。
public struct VideoExportConfiguration: Sendable, Equatable {
    public let profile: VideoExportProfile
    /// 是否保留音轨（PRD §4.6：无音 / 背景音乐二选一）。
    public let includeAudio: Bool

    public init(profile: VideoExportProfile, includeAudio: Bool = true) {
        self.profile = profile
        self.includeAudio = includeAudio
    }

    /// PRD V1 默认导出配置。
    public static let prdDefault = VideoExportConfiguration(profile: .full720p)

    /// 家庭圈预览版导出配置。
    public static let familyPreview = VideoExportConfiguration(profile: .familyPreview)
}
