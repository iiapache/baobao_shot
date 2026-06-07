import AVFoundation
@testable import BabyCameraCamera

/// 单测用内存会话，不依赖真机摄像头。
@MainActor
final class MockCameraSession: CameraSessionControlling, SessionPresetControlling, @unchecked Sendable {
    let captureSession = AVCaptureSession()
    private(set) var lifecycle: CameraSessionLifecycle = .idle
    private(set) var configuration: CameraConfiguration = .default
    var onFirstPreviewFrame: (@Sendable () -> Void)?
    var photoOutputController: (any PhotoOutputControlling)?
    var currentSessionPreset: AVCaptureSession.Preset = .photo
    var presetChanges: [AVCaptureSession.Preset] = []
    var shouldFailPresetChange = false

    var configureCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
    var switchCallCount = 0
    var flashCallCount = 0
    var shouldFailConfigure = false

    func configure(with configuration: CameraConfiguration) throws {
        configureCallCount += 1
        if shouldFailConfigure {
            lifecycle = .failed(.configurationFailed)
            throw CameraSessionError.configurationFailed
        }
        self.configuration = configuration
        lifecycle = .idle
    }

    func startRunning() throws {
        startCallCount += 1
        lifecycle = .running
        onFirstPreviewFrame?()
    }

    func stopRunning() {
        stopCallCount += 1
        lifecycle = .idle
    }

    func switchCamera() throws {
        switchCallCount += 1
        var next = configuration
        next.toggleCamera()
        configuration = next
    }

    func setFlashMode(_ mode: CameraFlashMode) throws {
        flashCallCount += 1
        configuration.flashMode = mode
    }

    func setSessionInterrupted(_ interrupted: Bool) {
        lifecycle = interrupted ? .interrupted : .running
    }

    func setSessionPreset(_ preset: AVCaptureSession.Preset) throws {
        if shouldFailPresetChange {
            throw PhotoCaptureError.sessionPresetUnavailable
        }
        currentSessionPreset = preset
        presetChanges.append(preset)
    }
}
