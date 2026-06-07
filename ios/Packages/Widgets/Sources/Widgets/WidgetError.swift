import Foundation

public enum WidgetError: Error, Equatable, Sendable {
    case appGroupUnavailable
    case sourceImageUnreadable(URL)
    case thumbnailGenerationFailed
    case snapshotWriteFailed
}
