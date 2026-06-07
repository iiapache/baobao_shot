import BabyCameraImageKit
import Foundation

/// PhotoOut → ImageKit 编码 → 文件系统 的拍摄管线。
public final class PhotoCapturePipeline: @unchecked Sendable {
    private let photoOutput: any PhotoOutputControlling
    private let codec: any ImageCodecProtocol
    private let fileWriter: any PhotoFileWriting
    private let lock = NSLock()
    private var isCapturing = false

    public init(
        photoOutput: any PhotoOutputControlling,
        codec: any ImageCodecProtocol = ImageCodec(),
        fileWriter: any PhotoFileWriting
    ) {
        self.photoOutput = photoOutput
        self.codec = codec
        self.fileWriter = fileWriter
    }

    /// 标准照片拍摄。
    public func capturePhoto(
        preferences: PhotoCapturePreferences = .default,
        flashMode: CameraFlashMode = .auto,
        overlayInfo: CameraOverlayInfo? = nil,
        settings: CameraSettings = .default,
        watermarkHook: CameraWatermarkHook? = nil
    ) async throws -> PhotoOut {
        let request = PhotoCaptureRequest(
            format: preferences.preferredFormat,
            flashMode: flashMode,
            isLivePhoto: false
        )
        return try await capture(
            request: request,
            preferences: preferences,
            overlayInfo: overlayInfo,
            settings: settings,
            watermarkHook: watermarkHook
        )
    }

    /// Live Photo 拍摄。
    public func captureLivePhoto(
        capturer: LivePhotoCapturer,
        preferences: PhotoCapturePreferences = .default,
        flashMode: CameraFlashMode = .auto,
        overlayInfo: CameraOverlayInfo? = nil,
        settings: CameraSettings = .default,
        watermarkHook: CameraWatermarkHook? = nil
    ) async throws -> PhotoOut {
        try capturer.configureOutput(photoOutput)
        let request = try capturer.makeRequest(preferences: preferences, flashMode: flashMode)
        return try await capture(
            request: request,
            preferences: preferences,
            overlayInfo: overlayInfo,
            settings: settings,
            watermarkHook: watermarkHook
        )
    }

    // MARK: - Internal

    func capture(
        request: PhotoCaptureRequest,
        preferences: PhotoCapturePreferences,
        overlayInfo: CameraOverlayInfo? = nil,
        settings: CameraSettings = .default,
        watermarkHook: CameraWatermarkHook? = nil
    ) async throws -> PhotoOut {
        try acquireCaptureSlot()

        let startedAt = CFAbsoluteTimeGetCurrent()
        defer { releaseCaptureSlot() }

        let raw = try await performCapture(request: request)
        let photoID = UUID()
        let encoded = try encode(raw: raw, preferences: preferences)
        let fileURL = try fileWriter.write(
            data: encoded.data,
            format: encoded.format,
            photoID: photoID,
            capturedAt: raw.capturedAt
        )

        let latency = CFAbsoluteTimeGetCurrent() - startedAt
        var result = PhotoOut(
            id: photoID,
            fileURL: fileURL,
            format: encoded.format,
            livePhotoMovieURL: raw.livePhotoMovieURL,
            capturedAt: raw.capturedAt,
            captureLatency: latency,
            didFallbackToJPEG: encoded.didFallbackToJPEG
        )

        if settings.burnInWatermark, let overlayInfo, let watermarkHook {
            let watermarkedURL = try await watermarkHook(
                CameraWatermarkRequest(
                    sourceFileURL: result.fileURL,
                    overlayInfo: overlayInfo,
                    format: result.format
                )
            )
            result = PhotoOut(
                id: result.id,
                fileURL: watermarkedURL,
                format: result.format,
                livePhotoMovieURL: result.livePhotoMovieURL,
                capturedAt: result.capturedAt,
                captureLatency: result.captureLatency,
                didFallbackToJPEG: result.didFallbackToJPEG
            )
        }

        return result
    }

    private func acquireCaptureSlot() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isCapturing else { throw PhotoCaptureError.captureInProgress }
        isCapturing = true
    }

    private func releaseCaptureSlot() {
        lock.lock()
        isCapturing = false
        lock.unlock()
    }

    private func performCapture(request: PhotoCaptureRequest) async throws -> RawPhotoCapture {
        try await withCheckedThrowingContinuation { continuation in
            photoOutput.capturePhoto(request: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func encode(
        raw: RawPhotoCapture,
        preferences: PhotoCapturePreferences
    ) throws -> EncodedImage {
        let image = try codec.decode(data: raw.imageData)
        return try codec.encode(
            image: image,
            format: preferences.preferredFormat,
            quality: preferences.jpegQuality
        )
    }
}
