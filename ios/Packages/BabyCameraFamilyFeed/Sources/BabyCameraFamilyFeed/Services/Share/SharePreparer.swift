import BabyCameraImageKit
import BabyCameraVideoKit
import BabyCameraWatermark
import CoreGraphics
import Foundation

public enum SharePreparerError: Error, Equatable, Sendable {
    case gateFailed(ShareGateError)
    case watermarkFailed
    case thumbnailFailed
    case videoExportFailed
}

/// 分享前媒体准备：经 `WatermarkRenderer` 合成后输出可分享文件（T5.15）。
public protocol SharePreparing: Sendable {
    func prepare(_ request: SharePreparationRequest) async throws -> SharePreparedAsset
}

public struct SharePreparer: SharePreparing {
    private let gate: ShareGate
    private let renderer: any WatermarkRendering
    private let codec: any ImageCodecProtocol
    private let thumbnailExtractor: any VideoThumbnailExtracting
    private let videoExporter: any VideoExporting
    private let fileManager: FileManager

    public init(
        gate: ShareGate = ShareGate(),
        renderer: any WatermarkRendering = WatermarkRenderer(),
        codec: any ImageCodecProtocol = ImageCodec(),
        thumbnailExtractor: any VideoThumbnailExtracting = VideoThumbnailExtractor(),
        videoExporter: any VideoExporting = VideoExporter(),
        fileManager: FileManager = .default
    ) {
        self.gate = gate
        self.renderer = renderer
        self.codec = codec
        self.thumbnailExtractor = thumbnailExtractor
        self.videoExporter = videoExporter
        self.fileManager = fileManager
    }

    public func prepare(_ request: SharePreparationRequest) async throws -> SharePreparedAsset {
        do {
            try gate.validate(request)
        } catch let error as ShareGateError {
            throw SharePreparerError.gateFailed(error)
        }

        let options = gate.watermarkOptions(for: request)
        let appliedBrandWatermark = renderer.shouldShowBrandWatermark(isSubscribed: request.isSubscribed)

        switch request.mediaKind {
        case .image:
            let mediaURL = try prepareImage(
                request: request,
                options: options
            )
            return SharePreparedAsset(
                mediaURL: mediaURL,
                thumbnailURL: nil,
                mediaKind: .image,
                appliedDeepSynthesisBadge: options.includeDeepSynthesisBadge,
                appliedBrandWatermark: appliedBrandWatermark
            )

        case .video:
            let mediaURL = try await prepareVideo(request: request)
            let thumbnailURL = try await prepareVideoThumbnail(
                request: request,
                options: options
            )
            return SharePreparedAsset(
                mediaURL: mediaURL,
                thumbnailURL: thumbnailURL,
                mediaKind: .video,
                appliedDeepSynthesisBadge: options.includeDeepSynthesisBadge,
                appliedBrandWatermark: appliedBrandWatermark
            )
        }
    }

    private func prepareImage(
        request: SharePreparationRequest,
        options: WatermarkRenderOptions
    ) throws -> URL {
        let format = imageFormat(for: request.sourceURL)
        let destinationURL = makeWorkDirectory()
            .appendingPathComponent("share-image.\(format.fileExtension)")

        do {
            return try renderer.render(
                sourceFileURL: request.sourceURL,
                format: format,
                isSubscribed: request.isSubscribed,
                destinationURL: destinationURL,
                options: options
            )
        } catch {
            throw SharePreparerError.watermarkFailed
        }
    }

    private func prepareVideo(request: SharePreparationRequest) async throws -> URL {
        guard request.reencodeVideo else {
            return request.sourceURL
        }

        let destinationURL = makeWorkDirectory().appendingPathComponent("share-video.mp4")
        do {
            return try await videoExporter.export(
                sourceURL: request.sourceURL,
                destinationURL: destinationURL,
                configuration: request.videoExportConfiguration,
                progressHandler: nil
            )
        } catch {
            throw SharePreparerError.videoExportFailed
        }
    }

    private func prepareVideoThumbnail(
        request: SharePreparationRequest,
        options: WatermarkRenderOptions
    ) async throws -> URL {
        let frame: CGImage
        do {
            frame = try await thumbnailExtractor.extractThumbnail(
                from: request.sourceURL,
                at: 0,
                maxEdgeLength: 512
            )
        } catch {
            throw SharePreparerError.thumbnailFailed
        }

        let watermarked: CGImage
        do {
            watermarked = try renderer.drawAllWatermarks(
                on: frame,
                isSubscribed: request.isSubscribed,
                options: options
            )
        } catch {
            throw SharePreparerError.watermarkFailed
        }

        let encoded: EncodedImage
        do {
            encoded = try codec.encode(image: watermarked, format: .jpeg)
        } catch {
            throw SharePreparerError.watermarkFailed
        }

        let destinationURL = makeWorkDirectory().appendingPathComponent("share-thumb.jpg")
        do {
            try encoded.data.write(to: destinationURL, options: .atomic)
        } catch {
            throw SharePreparerError.watermarkFailed
        }
        return destinationURL
    }

    private func makeWorkDirectory() -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("share-prep-\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
