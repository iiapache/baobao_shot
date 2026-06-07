import Foundation

/// 相机会话生命周期状态。
public enum CameraSessionLifecycle: Equatable, Sendable {
    case idle
    case configuring
    case running
    case interrupted
    case failed(CameraSessionError)
}

/// 会话层可恢复错误。
public enum CameraSessionError: Error, Equatable, Sendable {
    case cameraUnavailable
    case configurationFailed
    case permissionDenied
    case alreadyRunning
}

/// 取景器 UI 状态（权限、倒计时、首帧、信息浮层）。
public struct CameraViewState: Equatable, Sendable {
    public var lifecycle: CameraSessionLifecycle
    public var configuration: CameraConfiguration
    public var permissionDenied: Bool
    public var countdownRemaining: Int?
    public var hasReceivedFirstFrame: Bool
    public var overlayInfo: CameraOverlayInfo?

    public init(
        lifecycle: CameraSessionLifecycle = .idle,
        configuration: CameraConfiguration = .default,
        permissionDenied: Bool = false,
        countdownRemaining: Int? = nil,
        hasReceivedFirstFrame: Bool = false,
        overlayInfo: CameraOverlayInfo? = nil
    ) {
        self.lifecycle = lifecycle
        self.configuration = configuration
        self.permissionDenied = permissionDenied
        self.countdownRemaining = countdownRemaining
        self.hasReceivedFirstFrame = hasReceivedFirstFrame
        self.overlayInfo = overlayInfo
    }

    public var isCountingDown: Bool {
        guard let remaining = countdownRemaining else { return false }
        return remaining > 0
    }
}

/// 可观察的相机状态容器，便于单测与 SwiftUI 桥接。
@MainActor
public final class CameraState: ObservableObject {
    @Published public private(set) var viewState: CameraViewState

    public var configuration: CameraConfiguration {
        get { viewState.configuration }
        set { viewState.configuration = newValue }
    }

    public init(viewState: CameraViewState = CameraViewState()) {
        self.viewState = viewState
    }

    public func updateConfiguration(_ transform: (inout CameraConfiguration) -> Void) {
        var config = viewState.configuration
        transform(&config)
        viewState.configuration = config
    }

    public func setLifecycle(_ lifecycle: CameraSessionLifecycle) {
        viewState.lifecycle = lifecycle
    }

    public func setPermissionDenied(_ denied: Bool) {
        viewState.permissionDenied = denied
    }

    public func setCountdownRemaining(_ seconds: Int?) {
        viewState.countdownRemaining = seconds
    }

    public func markFirstFrameReceived() {
        viewState.hasReceivedFirstFrame = true
    }

    public func resetFirstFrame() {
        viewState.hasReceivedFirstFrame = false
    }

    public func setOverlayInfo(_ info: CameraOverlayInfo?) {
        viewState.overlayInfo = info
    }
}
