import Foundation

/// VideoKit 操作错误。
public enum VideoKitError: Error, Equatable, Sendable {
    case invalidURL
    case assetNotPlayable
    case noVideoTrack
    case probeFailed
    case unsupportedContainer
    case unsupportedCodec
    case thumbnailFailed
    case exportSessionCreationFailed
    case exportFailed(status: Int)
    case exportCancelled
    case outputFileMissing
}
