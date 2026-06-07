import Foundation

/// Widget 专用缩略图档位（design-ios §11.3：200×200 / 600×600）。
public enum WidgetThumbnailSize: Int, Sendable, Equatable, CaseIterable {
    case small = 200
    case large = 600

    public var maxEdgeLength: Int { rawValue }

    public var fileSuffix: String { "\(rawValue)" }
}
