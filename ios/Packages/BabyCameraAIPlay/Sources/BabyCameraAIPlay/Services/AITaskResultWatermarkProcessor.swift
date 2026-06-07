import BabyCameraImageKit
import BabyCameraVideoKit
import BabyCameraWatermark
import Database
import Foundation

public enum AITaskResultWatermarkError: Error, Equatable, Sendable {
    case unsupportedImageFormat(String)
    case watermarkFailed(taskId: String)
    case thumbnailFailed(taskId: String)
}

public protocol AITaskResultWatermarkProcessing: Sendable {
    func applyWatermarksToImageFile(at url: URL, isSubscribed: Bool) throws
    func generateVideoCoverThumbnail(
        videoURL: URL,
        derivedId: String,
        isSubscribed: Bool
    ) async throws -> String
}

/// Applies mandatory deep-synthesis badge + optional brand watermark to AI results (T3.25).
public struct AITaskResultWatermarkProcessor: AITaskResultWatermarkProcessing, Sendable {
    private let storePaths: LocalStorePaths
    private let renderer: any WatermarkRendering
    private let thumbnailExtractor: any VideoThumbnailExtracting
    private let thumbnailGenerator: any ThumbnailGenerating
    private let codec: any ImageCodecProtocol
    private let fileManager: FileManager

    public init(
        storePaths: LocalStorePaths,
        renderer: any WatermarkRendering = WatermarkRenderer(),
        thumbnailExtractor: any VideoThumbnailExtracting = VideoThumbnailExtractor(),
        thumbnailGenerator: any ThumbnailGenerating = ThumbnailGenerator(),
        codec: any ImageCodecProtocol = ImageCodec(),
        fileManager: FileManager = .default
    ) {
        self.storePaths = storePaths
        self.renderer = renderer
        self.thumbnailExtractor = thumbnailExtractor
        self.thumbnailGenerator = thumbnailGenerator
        self.codec = codec
        self.fileManager = fileManager
    }

    public func applyWatermarksToImageFile(at url: URL, isSubscribed: Bool) throws {
        let format = imageFormat(for: url)
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".watermark-\(UUID().uuidString).\(format.fileExtension)")

        defer {
            try? fileManager.removeItem(at: tempURL)
        }

        _ = try renderer.render(
            sourceFileURL: url,
            format: format,
            isSubscribed: isSubscribed,
            destinationURL: tempURL,
            options: .aiResult
        )

        _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
    }

    public func generateVideoCoverThumbnail(
        videoURL: URL,
        derivedId: String,
        isSubscribed: Bool
    ) async throws -> String {
        let frame = try await thumbnailExtractor.extractThumbnail(
            from: videoURL,
            at: 0,
            maxEdgeLength: ThumbnailSize.small.maxEdgeLength
        )
        let watermarked = try renderer.drawAllWatermarks(
            on: frame,
            isSubscribed: isSubscribed,
            options: .aiResult
        )
        let thumbnail = try thumbnailGenerator.generate(from: watermarked, size: .small)
        let encoded = try codec.encode(image: thumbnail, format: .heic)

        let destination = try storePaths.ensureDirectory(
            for: storePaths.thumbnailFileURL(
                derivedId: derivedId,
                maxEdgeLength: ThumbnailSize.small.maxEdgeLength
            )
        )
        try encoded.data.write(to: destination, options: .atomic)
        return destination.path
    }

    private func imageFormat(for url: URL) -> ImageFormat {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return .jpeg
        default:
            return .heic
        }
    }
}
