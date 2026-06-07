import AVFoundation
import BabyCameraImageKit
import Foundation

/// 单次拍摄请求（抽象 `AVCapturePhotoSettings`，便于单测 mock）。
public struct PhotoCaptureRequest: Equatable, Sendable {
    public let format: ImageFormat
    public let flashMode: CameraFlashMode
    public let isLivePhoto: Bool
    public let livePhotoMovieURL: URL?

    public init(
        format: ImageFormat,
        flashMode: CameraFlashMode = .auto,
        isLivePhoto: Bool = false,
        livePhotoMovieURL: URL? = nil
    ) {
        self.format = format
        self.flashMode = flashMode
        self.isLivePhoto = isLivePhoto
        self.livePhotoMovieURL = livePhotoMovieURL
    }
}

/// 底层 `AVCapturePhotoOutput` 回调的原始拍摄数据。
public struct RawPhotoCapture: Equatable, Sendable {
    public let imageData: Data
    public let livePhotoMovieURL: URL?
    public let capturedAt: Date

    public init(
        imageData: Data,
        livePhotoMovieURL: URL? = nil,
        capturedAt: Date = Date()
    ) {
        self.imageData = imageData
        self.livePhotoMovieURL = livePhotoMovieURL
        self.capturedAt = capturedAt
    }
}

/// 可注入的 PhotoOut 控制协议，便于单测与性能基准。
public protocol PhotoOutputControlling: AnyObject, Sendable {
    var isLivePhotoCaptureSupported: Bool { get }
    var isLivePhotoCaptureEnabled: Bool { get set }

    func capturePhoto(
        request: PhotoCaptureRequest,
        completion: @escaping @Sendable (Result<RawPhotoCapture, PhotoCaptureError>) -> Void
    )
}

/// 会话预设控制，连拍时切换 `.high`。
public protocol SessionPresetControlling: AnyObject, Sendable {
    var currentSessionPreset: AVCaptureSession.Preset { get }
    func setSessionPreset(_ preset: AVCaptureSession.Preset) throws
}

/// `AVCapturePhotoOutput` 生产实现。
public final class AVCapturePhotoOutputController: NSObject, PhotoOutputControlling, @unchecked Sendable {
    private let output: AVCapturePhotoOutput
    private let captureQueue: DispatchQueue

    public var isLivePhotoCaptureSupported: Bool {
        output.isLivePhotoCaptureSupported
    }

    public var isLivePhotoCaptureEnabled: Bool {
        get { output.isLivePhotoCaptureEnabled }
        set { output.isLivePhotoCaptureEnabled = newValue }
    }

    public init(
        output: AVCapturePhotoOutput,
        captureQueue: DispatchQueue = DispatchQueue(
            label: "app.babycamera.camera.photo-capture",
            qos: .userInitiated
        )
    ) {
        self.output = output
        self.captureQueue = captureQueue
        super.init()
    }

    public func capturePhoto(
        request: PhotoCaptureRequest,
        completion: @escaping @Sendable (Result<RawPhotoCapture, PhotoCaptureError>) -> Void
    ) {
        guard let settings = Self.makeAVSettings(from: request, output: output) else {
            completion(.failure(.captureFailed))
            return
        }

        let delegate = PhotoCaptureDelegate(
            livePhotoMovieURL: request.livePhotoMovieURL,
            completion: completion
        )
        output.capturePhoto(with: settings, delegate: delegate)
    }

    // MARK: - Settings

    static func makeAVSettings(
        from request: PhotoCaptureRequest,
        output: AVCapturePhotoOutput
    ) -> AVCapturePhotoSettings? {
        let settings: AVCapturePhotoSettings

        if request.isLivePhoto, let movieURL = request.livePhotoMovieURL {
            guard output.isLivePhotoCaptureSupported else { return nil }
            if let codec = preferredCodec(for: request.format, output: output) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.livePhotoMovieFileURL = movieURL
        } else if let codec = preferredCodec(for: request.format, output: output) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])
        } else {
            settings = AVCapturePhotoSettings()
        }

        if let avFlash = flashMode(for: request.flashMode) {
            settings.flashMode = avFlash
        }

        if #available(iOS 13.0, *) {
            if output.maxPhotoQualityPrioritization.rawValue >= AVCapturePhotoOutput.QualityPrioritization.speed.rawValue {
                settings.photoQualityPrioritization = .speed
            }
        }

        return settings
    }

    static func preferredCodec(
        for format: ImageFormat,
        output: AVCapturePhotoOutput
    ) -> AVVideoCodecType? {
        let available = output.availablePhotoCodecTypes
        switch format {
        case .heic:
            if available.contains(.hevc) { return .hevc }
            if available.contains(.jpeg) { return .jpeg }
            return available.first
        case .jpeg:
            if available.contains(.jpeg) { return .jpeg }
            return available.first
        }
    }

    static func flashMode(for mode: CameraFlashMode) -> AVCaptureDevice.FlashMode? {
        switch mode {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }
}

// MARK: - Delegate

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let livePhotoMovieURL: URL?
    private let completion: @Sendable (Result<RawPhotoCapture, PhotoCaptureError>) -> Void
    private let lock = NSLock()
    private var didFinish = false

    init(
        livePhotoMovieURL: URL?,
        completion: @escaping @Sendable (Result<RawPhotoCapture, PhotoCaptureError>) -> Void
    ) {
        self.livePhotoMovieURL = livePhotoMovieURL
        self.completion = completion
        super.init()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        finish {
            if let error {
                _ = error
                return .failure(.captureFailed)
            }
            guard let data = photo.fileDataRepresentation(), !data.isEmpty else {
                return .failure(.captureFailed)
            }
            return .success(
                RawPhotoCapture(
                    imageData: data,
                    livePhotoMovieURL: self.livePhotoMovieURL,
                    capturedAt: Date()
                )
            )
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if error != nil {
            finish { .failure(.captureFailed) }
        }
    }

    private func finish(_ makeResult: () -> Result<RawPhotoCapture, PhotoCaptureError>) {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return }
        didFinish = true
        completion(makeResult())
    }
}
