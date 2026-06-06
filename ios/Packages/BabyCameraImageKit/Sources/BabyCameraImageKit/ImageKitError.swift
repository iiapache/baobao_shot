import Foundation

/// ImageKit 操作错误。
public enum ImageKitError: Error, Equatable, Sendable {
    case invalidData
    case decodeFailed
    case encodeFailed
    case thumbnailFailed
}
