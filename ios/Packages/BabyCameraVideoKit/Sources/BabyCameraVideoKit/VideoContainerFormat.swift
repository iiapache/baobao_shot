import Foundation

/// 视频容器格式。
public enum VideoContainerFormat: String, Sendable, Equatable, CaseIterable {
    case mp4
    case mov
    case unknown

    /// PRD §4.6 要求输出 MP4。
    public var isPRDCompliant: Bool {
        self == .mp4
    }
}
