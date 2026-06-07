import Foundation

/// T2.7 拍摄性能预算（design-ios §7.2 / dev-plan 验收）。
public enum PhotoCaptureBenchmark {
    /// 单次拍摄延迟预算（毫秒）。
    public static let captureLatencyBudgetMilliseconds = 200
    /// 连拍目标帧率（帧/秒）。
    public static let burstTargetFramesPerSecond = 10

    public struct Measurement: Equatable, Sendable {
        public let latencyMilliseconds: Int
        public let withinCaptureBudget: Bool

        public init(latencySeconds: TimeInterval) {
            let ms = Int((latencySeconds * 1000).rounded())
            self.latencyMilliseconds = ms
            self.withinCaptureBudget = ms <= captureLatencyBudgetMilliseconds
        }
    }

    public struct BurstMeasurement: Equatable, Sendable {
        public let frameCount: Int
        public let durationSeconds: TimeInterval
        public let framesPerSecond: Double
        public let meetsTarget: Bool

        public init(frameCount: Int, durationSeconds: TimeInterval) {
            self.frameCount = frameCount
            self.durationSeconds = durationSeconds
            if durationSeconds > 0 {
                self.framesPerSecond = Double(frameCount) / durationSeconds
            } else {
                self.framesPerSecond = 0
            }
            self.meetsTarget = framesPerSecond >= Double(burstTargetFramesPerSecond)
        }
    }

    public static func measure(latencySeconds: TimeInterval) -> Measurement {
        Measurement(latencySeconds: latencySeconds)
    }

    public static func measureBurst(frameCount: Int, durationSeconds: TimeInterval) -> BurstMeasurement {
        BurstMeasurement(frameCount: frameCount, durationSeconds: durationSeconds)
    }
}
