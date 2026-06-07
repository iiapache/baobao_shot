import Foundation

public enum AIPlayKind: String, Sendable, Equatable, CaseIterable {
    case image
    case video
    case text

    public init(rawKind: String) {
        self = AIPlayKind(rawValue: rawKind) ?? .image
    }

    public var displayName: String {
        switch self {
        case .image:
            return "图像"
        case .video:
            return "视频"
        case .text:
            return "文案"
        }
    }

    public var systemImageName: String {
        switch self {
        case .image:
            return "photo.artframe"
        case .video:
            return "video.fill"
        case .text:
            return "text.quote"
        }
    }
}
