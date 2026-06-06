import AVFoundation
import CoreMedia
import Foundation
import UniformTypeIdentifiers

/// 视频探测协议，便于单测注入 mock。
public protocol VideoProbing: Sendable {
    func probe(url: URL) async throws -> VideoProbeResult
}

/// AVFoundation 视频探测实现（MP4/H.264 识别）。
public struct VideoProbe: VideoProbing {
    public init() {}

    public func probe(url: URL) async throws -> VideoProbeResult {
        guard url.isFileURL || url.scheme == "file" else {
            throw VideoKitError.invalidURL
        }

        let asset = AVURLAsset(url: url)
        return try await probe(asset: asset, sourceURL: url)
    }

    func probe(asset: AVAsset, sourceURL: URL) async throws -> VideoProbeResult {
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw VideoKitError.assetNotPlayable
        }

        let tracks = try await asset.load(.tracks)
        let videoTracks = tracks.filter { $0.mediaType == .video }
        guard let videoTrack = videoTracks.first else {
            throw VideoKitError.noVideoTrack
        }

        let audioTracks = tracks.filter { $0.mediaType == .audio }
        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let formatDescriptions = try await videoTrack.load(.formatDescriptions)

        let containerFormat = Self.detectContainerFormat(url: sourceURL)
        let videoCodec = Self.detectVideoCodec(from: formatDescriptions)

        return VideoProbeResult(
            containerFormat: containerFormat,
            videoCodec: videoCodec,
            duration: CMTimeGetSeconds(duration),
            naturalSize: naturalSize,
            hasAudioTrack: !audioTracks.isEmpty,
            frameRate: nominalFrameRate
        )
    }

    // MARK: - Private

    private static func detectContainerFormat(url: URL) -> VideoContainerFormat {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "m4v":
            return .mp4
        case "mov":
            return .mov
        default:
            if let type = UTType(filenameExtension: ext) {
                if type.conforms(to: .mpeg4Movie) {
                    return .mp4
                }
                if type.conforms(to: .quickTimeMovie) {
                    return .mov
                }
            }
            return .unknown
        }
    }

    private static func detectVideoCodec(from formatDescriptions: [CMFormatDescription]) -> VideoCodec {
        guard let formatDescription = formatDescriptions.first else {
            return .unknown
        }

        let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
        switch codecType {
        case kCMVideoCodecType_H264:
            return .h264
        case kCMVideoCodecType_HEVC:
            return .hevc
        default:
            return .unknown
        }
    }
}
