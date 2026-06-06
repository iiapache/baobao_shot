import AVFoundation
import Foundation

/// 视频导出协议，便于单测注入 mock。
public protocol VideoExporting: Sendable {
    func export(
        sourceURL: URL,
        destinationURL: URL,
        configuration: VideoExportConfiguration,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> URL
}

/// AVAssetExportSession 包装实现。
public struct VideoExporter: VideoExporting {
    public init() {}

    public func export(
        sourceURL: URL,
        destinationURL: URL,
        configuration: VideoExportConfiguration = .prdDefault,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        guard try await asset.load(.isPlayable) else {
            throw VideoKitError.assetNotPlayable
        }

        let preset = configuration.profile.exportPresetName
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw VideoKitError.exportSessionCreationFailed
        }

        if destinationURL.isFileURL {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        session.outputURL = destinationURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = configuration.profile == .familyPreview

        if !configuration.includeAudio {
            let tracks = try await asset.load(.tracks)
            let audioTracks = tracks.filter { $0.mediaType == .audio }
            if !audioTracks.isEmpty {
                let composition = AVMutableComposition()
                guard
                    let videoTrack = tracks.first(where: { $0.mediaType == .video }),
                    let compositionVideoTrack = composition.addMutableTrack(
                        withMediaType: .video,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                else {
                    throw VideoKitError.exportSessionCreationFailed
                }

                let duration = try await asset.load(.duration)
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

                guard let mutedSession = AVAssetExportSession(
                    asset: composition,
                    presetName: preset
                ) else {
                    throw VideoKitError.exportSessionCreationFailed
                }

                mutedSession.outputURL = destinationURL
                mutedSession.outputFileType = .mp4
                mutedSession.shouldOptimizeForNetworkUse = configuration.profile == .familyPreview
                return try await runExport(session: mutedSession, progressHandler: progressHandler)
            }
        }

        return try await runExport(session: session, progressHandler: progressHandler)
    }

    // MARK: - Private

    private func runExport(
        session: AVAssetExportSession,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        guard let outputURL = session.outputURL else {
            throw VideoKitError.exportSessionCreationFailed
        }

        let progressTask: Task<Void, Never>? = progressHandler.map { handler in
            Task {
                while !Task.isCancelled {
                    handler(Double(session.progress))
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }

        await withCheckedContinuation { continuation in
            session.exportAsynchronously {
                continuation.resume()
            }
        }

        progressTask?.cancel()

        switch session.status {
        case .completed:
            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw VideoKitError.outputFileMissing
            }
            return outputURL

        case .cancelled:
            throw VideoKitError.exportCancelled

        case .failed:
            throw VideoKitError.exportFailed(status: session.status.rawValue)

        default:
            throw VideoKitError.exportFailed(status: session.status.rawValue)
        }
    }
}
