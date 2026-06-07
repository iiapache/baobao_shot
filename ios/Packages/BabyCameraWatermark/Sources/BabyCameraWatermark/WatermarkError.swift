import Foundation

public enum WatermarkError: Error, Equatable, Sendable {
    case sourceFileUnreadable
    case renderFailed
    case writeFailed
}
