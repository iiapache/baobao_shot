import Foundation

/// MetadataWriter 写入错误。
public enum MetadataError: Error, Equatable, Sendable {
    case missingDateTimeOriginal
    case emptyBabyIds
    case fileNotReadable
    case persistenceFailed(String)
}
