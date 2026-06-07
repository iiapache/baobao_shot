import Foundation

public enum EditorRenderError: Error, Equatable, Sendable {
    case metalUnavailable
    case invalidExtent
    case renderFailed
    case mmapFailed
}
