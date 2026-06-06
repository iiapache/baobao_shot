import Foundation

/// 视频编码格式。
public enum VideoCodec: String, Sendable, Equatable, CaseIterable {
    case h264
    case hevc
    case unknown

    /// PRD §4.6 要求 H.264。
    public var isPRDCompliant: Bool {
        self == .h264
    }
}
