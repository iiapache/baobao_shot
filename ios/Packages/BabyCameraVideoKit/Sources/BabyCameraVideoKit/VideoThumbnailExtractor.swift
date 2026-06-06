import AVFoundation
import CoreGraphics
import Foundation

/// 视频缩略图抽帧协议。
public protocol VideoThumbnailExtracting: Sendable {
    func extractThumbnail(
        from url: URL,
        at seconds: TimeInterval,
        maxEdgeLength: Int
    ) async throws -> CGImage
}

/// 基于 AVAssetImageGenerator 的缩略图抽帧实现。
public struct VideoThumbnailExtractor: VideoThumbnailExtracting {
    public static let defaultMaxEdgeLength = 256

    public init() {}

    public func extractThumbnail(
        from url: URL,
        at seconds: TimeInterval = 0,
        maxEdgeLength: Int = Self.defaultMaxEdgeLength
    ) async throws -> CGImage {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 0 else {
            throw VideoKitError.thumbnailFailed
        }

        let clampedSeconds = min(max(seconds, 0), max(durationSeconds - 0.001, 0))
        let time = CMTime(seconds: clampedSeconds, preferredTimescale: 600)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        let maxEdge = max(1, maxEdgeLength)
        generator.maximumSize = CGSize(width: maxEdge, height: maxEdge)

        let cgImage: CGImage
        do {
            let result = try await generator.image(at: time)
            cgImage = result.image
        } catch {
            throw VideoKitError.thumbnailFailed
        }

        return cgImage
    }
}
