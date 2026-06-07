import AVFoundation
import Foundation

/// 摄像头位置。
public enum CameraPosition: String, Codable, CaseIterable, Sendable, Hashable {
    case back
    case front

    public var avPosition: AVCaptureDevice.Position {
        switch self {
        case .back: return .back
        case .front: return .front
        }
    }

    public mutating func toggle() {
        self = self == .back ? .front : .back
    }
}

/// 闪光灯模式（PRD §4.3.1：自动 / 开 / 关）。
public enum CameraFlashMode: String, Codable, CaseIterable, Sendable, Hashable {
    case auto
    case on
    case off

    public var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }

    /// 按 PRD 顺序循环：auto → on → off → auto。
    public func next() -> CameraFlashMode {
        switch self {
        case .auto: return .on
        case .on: return .off
        case .off: return .auto
        }
    }
}

/// 倒计时拍摄时长（PRD §4.3.1：3s / 10s）。
public enum CameraCountdown: Int, Codable, CaseIterable, Sendable, Hashable {
    case off = 0
    case three = 3
    case ten = 10

    /// 循环：关 → 3s → 10s → 关。
    public func next() -> CameraCountdown {
        switch self {
        case .off: return .three
        case .three: return .ten
        case .ten: return .off
        }
    }

    public var isEnabled: Bool { self != .off }
}

/// 相机 UI 与行为配置，单一事实源。
public struct CameraConfiguration: Equatable, Sendable, Codable {
    public var position: CameraPosition
    public var flashMode: CameraFlashMode
    public var showsGrid: Bool
    public var showsLevel: Bool
    public var countdown: CameraCountdown

    public static let `default` = CameraConfiguration(
        position: .back,
        flashMode: .auto,
        showsGrid: false,
        showsLevel: false,
        countdown: .off
    )

    public init(
        position: CameraPosition = .back,
        flashMode: CameraFlashMode = .auto,
        showsGrid: Bool = false,
        showsLevel: Bool = false,
        countdown: CameraCountdown = .off
    ) {
        self.position = position
        self.flashMode = flashMode
        self.showsGrid = showsGrid
        self.showsLevel = showsLevel
        self.countdown = countdown
    }

    public mutating func toggleCamera() {
        position.toggle()
    }

    public mutating func cycleFlashMode() {
        flashMode = flashMode.next()
    }

    public mutating func cycleCountdown() {
        countdown = countdown.next()
    }
}
