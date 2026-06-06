import CoreGraphics
import Foundation

/// 视频探测结果。
public struct VideoProbeResult: Sendable, Equatable {
    public let containerFormat: VideoContainerFormat
    public let videoCodec: VideoCodec
    public let duration: TimeInterval
    public let naturalSize: CGSize
    public let hasAudioTrack: Bool
    public let frameRate: Float

    /// 是否符合 PRD §4.6（MP4 + H.264）。
    public var isPRDCompliant: Bool {
        containerFormat.isPRDCompliant && videoCodec.isPRDCompliant
    }

    public init(
        containerFormat: VideoContainerFormat,
        videoCodec: VideoCodec,
        duration: TimeInterval,
        naturalSize: CGSize,
        hasAudioTrack: Bool,
        frameRate: Float
    ) {
        self.containerFormat = containerFormat
        self.videoCodec = videoCodec
        self.duration = duration
        self.naturalSize = naturalSize
        self.hasAudioTrack = hasAudioTrack
        self.frameRate = frameRate
    }
}
