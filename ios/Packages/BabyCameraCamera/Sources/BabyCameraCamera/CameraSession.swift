import AVFoundation
import BabyCameraImageKit
import Foundation

/// 可注入的会话控制协议，便于单测与性能基准。
public protocol CameraSessionControlling: AnyObject, Sendable {
    var captureSession: AVCaptureSession { get }
    var lifecycle: CameraSessionLifecycle { get }
    var configuration: CameraConfiguration { get }
    var onFirstPreviewFrame: (@Sendable () -> Void)? { get set }
    var photoOutputController: (any PhotoOutputControlling)? { get }

    func configure(with configuration: CameraConfiguration) throws
    func startRunning() throws
    func stopRunning()
    func switchCamera() throws
    func setFlashMode(_ mode: CameraFlashMode) throws
    func setSessionInterrupted(_ interrupted: Bool)
}

/// `AVCaptureSession` 封装：生命周期、前后摄切换、闪光灯、PhotoOut。
public final class CameraSession: NSObject, CameraSessionControlling, SessionPresetControlling, @unchecked Sendable {
    public let captureSession = AVCaptureSession()
    public private(set) var lifecycle: CameraSessionLifecycle = .idle
    public private(set) var configuration: CameraConfiguration = .default

    private let sessionQueue = DispatchQueue(label: "app.babycamera.camera.session", qos: .userInitiated)
    private var videoInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var photoOutputAdapter: AVCapturePhotoOutputController?
    private var currentDevice: AVCaptureDevice?

    public var onFirstPreviewFrame: (@Sendable () -> Void)?

    public var photoOutputController: (any PhotoOutputControlling)? {
        photoOutputAdapter
    }

    public var currentSessionPreset: AVCaptureSession.Preset {
        captureSession.sessionPreset
    }

    private let deviceDiscovery: any CameraDeviceDiscovering

    public init(deviceDiscovery: any CameraDeviceDiscovering = LiveCameraDeviceDiscovery()) {
        self.deviceDiscovery = deviceDiscovery
        super.init()
        captureSession.sessionPreset = .photo
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidStartRunning),
            name: .AVCaptureSessionDidStartRunning,
            object: captureSession
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func configure(with configuration: CameraConfiguration) throws {
        lifecycle = .configuring
        self.configuration = configuration

        try sessionQueue.sync {
            captureSession.beginConfiguration()
            defer { captureSession.commitConfiguration() }

            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }
            for output in captureSession.outputs {
                captureSession.removeOutput(output)
            }

            guard let device = deviceDiscovery.device(for: configuration.position) else {
                lifecycle = .failed(.cameraUnavailable)
                throw CameraSessionError.cameraUnavailable
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else {
                lifecycle = .failed(.configurationFailed)
                throw CameraSessionError.configurationFailed
            }
            captureSession.addInput(input)
            videoInput = input
            currentDevice = device

            let output = AVCapturePhotoOutput()
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
                photoOutput = output
                photoOutputAdapter = AVCapturePhotoOutputController(output: output)
            } else {
                photoOutput = nil
                photoOutputAdapter = nil
            }

            try applyFlashMode(configuration.flashMode, on: device)
        }

        lifecycle = .idle
    }

    public func startRunning() throws {
        guard lifecycle != .running else { throw CameraSessionError.alreadyRunning }

        if lifecycle == .idle || lifecycle == .interrupted {
            if videoInput == nil {
                try configure(with: configuration)
            }
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            } else {
                DispatchQueue.main.async {
                    self.lifecycle = .running
                    self.onFirstPreviewFrame?()
                }
            }
        }
    }

    public func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            DispatchQueue.main.async {
                self.lifecycle = .idle
            }
        }
    }

    public func switchCamera() throws {
        var next = configuration
        next.toggleCamera()
        try configure(with: next)
        if captureSession.isRunning {
            lifecycle = .running
        }
    }

    public func setFlashMode(_ mode: CameraFlashMode) throws {
        configuration.flashMode = mode
        guard let device = currentDevice else { return }
        try applyFlashMode(mode, on: device)
    }

    public func setSessionInterrupted(_ interrupted: Bool) {
        lifecycle = interrupted ? .interrupted : .running
    }

    public func setSessionPreset(_ preset: AVCaptureSession.Preset) throws {
        try sessionQueue.sync {
            guard captureSession.canSetSessionPreset(preset) else {
                throw PhotoCaptureError.sessionPresetUnavailable
            }
            captureSession.beginConfiguration()
            captureSession.sessionPreset = preset
            captureSession.commitConfiguration()
        }
    }

    /// 基于当前 PhotoOut 构建拍摄管线。
    public func makePhotoCapturePipeline(
        outputDirectory: URL,
        codec: any ImageCodecProtocol = ImageCodec()
    ) throws -> PhotoCapturePipeline {
        guard let controller = photoOutputController else {
            throw PhotoCaptureError.outputUnavailable
        }
        let writer = PhotoFileWriter(baseDirectory: outputDirectory)
        return PhotoCapturePipeline(
            photoOutput: controller,
            codec: codec,
            fileWriter: writer
        )
    }

    // MARK: - Notifications

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        lifecycle = .interrupted
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        if captureSession.isRunning {
            lifecycle = .running
        }
    }

    @objc private func sessionDidStartRunning(_ notification: Notification) {
        lifecycle = .running
        onFirstPreviewFrame?()
    }

    // MARK: - Flash

    private func applyFlashMode(_ mode: CameraFlashMode, on device: AVCaptureDevice) throws {
        guard device.hasFlash else { return }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isFlashModeSupported(mode.avFlashMode) {
            device.flashMode = mode.avFlashMode
        }
    }
}

// MARK: - Device discovery

public protocol CameraDeviceDiscovering: Sendable {
    func device(for position: CameraPosition) -> AVCaptureDevice?
}

public struct LiveCameraDeviceDiscovery: CameraDeviceDiscovering {
    public init() {}

    public func device(for position: CameraPosition) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition)
    }
}

/// 单测用模拟设备发现，不依赖真机摄像头。
public struct MockCameraDeviceDiscovery: CameraDeviceDiscovering {
    public var availablePositions: Set<CameraPosition>

    public init(availablePositions: Set<CameraPosition> = [.back, .front]) {
        self.availablePositions = availablePositions
    }

    public func device(for position: CameraPosition) -> AVCaptureDevice? {
        guard availablePositions.contains(position) else { return nil }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition)
    }
}
