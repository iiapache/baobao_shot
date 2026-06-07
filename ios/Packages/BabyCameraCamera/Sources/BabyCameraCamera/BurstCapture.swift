import AVFoundation
import Foundation

/// 连拍控制器：会话预设 `.high`，目标 10 帧/秒（PRD §4.3.1 / design-ios §7.2）。
public final class BurstCapture: @unchecked Sendable {
    public static let defaultPreset: AVCaptureSession.Preset = .high
    public static let targetIntervalSeconds: TimeInterval = 1.0 / Double(PhotoCaptureBenchmark.burstTargetFramesPerSecond)

    private let pipeline: PhotoCapturePipeline
    private let sessionPresetController: any SessionPresetControlling
    private let clock: any BurstClock
    private let lock = NSLock()
    private var isBursting = false
    private var burstTask: Task<Void, Never>?

    public private(set) var capturedPhotos: [PhotoOut] = []

    public init(
        pipeline: PhotoCapturePipeline,
        sessionPresetController: any SessionPresetControlling,
        clock: any BurstClock = SystemBurstClock()
    ) {
        self.pipeline = pipeline
        self.sessionPresetController = sessionPresetController
        self.clock = clock
    }

    /// 开始连拍；`maxFrames` 为 nil 时由调用方通过 `stopBurst()` 结束。
    public func startBurst(
        preferences: PhotoCapturePreferences = .default,
        flashMode: CameraFlashMode = .auto,
        maxFrames: Int? = nil
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isBursting else { throw PhotoCaptureError.captureInProgress }

        try sessionPresetController.setSessionPreset(Self.defaultPreset)
        isBursting = true
        capturedPhotos = []

        burstTask = Task { [weak self] in
            guard let self else { return }
            var frameCount = 0
            while !Task.isCancelled {
                let stillBursting = self.lock.withLock { self.isBursting }
                guard stillBursting else { break }
                if let maxFrames, frameCount >= maxFrames { break }

                do {
                    let photo = try await self.pipeline.capturePhoto(
                        preferences: preferences,
                        flashMode: flashMode
                    )
                    self.lock.withLock {
                        self.capturedPhotos.append(photo)
                    }
                    frameCount += 1
                } catch {
                    break
                }

                try? await self.clock.sleep(for: Self.targetIntervalSeconds)
            }
            self.lock.withLock { self.isBursting = false }
            self.restorePresetAfterBurst()
        }
    }

    /// 停止连拍并恢复会话预设。
    @discardableResult
    public func stopBurst() -> [PhotoOut] {
        lock.lock()
        isBursting = false
        let photos = capturedPhotos
        lock.unlock()

        burstTask?.cancel()
        burstTask = nil
        restorePresetAfterBurst()
        return photos
    }

    public var isActive: Bool {
        lock.withLock { isBursting }
    }

    private func restorePresetAfterBurst() {
        try? sessionPresetController.setSessionPreset(.photo)
    }
}

/// 可注入时钟，单测无需真实等待。
public protocol BurstClock: Sendable {
    func sleep(for interval: TimeInterval) async throws
}

public struct SystemBurstClock: BurstClock {
    public init() {}

    public func sleep(for interval: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
