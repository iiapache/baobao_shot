import BabyCameraDiagnostics
import Foundation

/// 相机启动性能基准（design-ios §7.2 / §14：≤ 800ms）。
public enum CameraStartupBenchmark {
    /// 预算上限（毫秒）。
    public static let budgetMilliseconds: Int = PerformanceTracker.cameraColdStartBudgetMs

    public struct Measurement: Equatable, Sendable {
        public let elapsedMilliseconds: Int
        public let withinBudget: Bool

        public init(elapsedMilliseconds: Int) {
            self.elapsedMilliseconds = elapsedMilliseconds
            self.withinBudget = elapsedMilliseconds <= CameraStartupBenchmark.budgetMilliseconds
        }
    }

    /// 将秒级耗时转为基准测量结果，并经由 `PerformanceTracker` 输出日志与埋点。
    public static func measure(elapsedSeconds: TimeInterval, source: String = "benchmark") -> Measurement {
        let tracked = PerformanceTracker.recordCameraColdStart(elapsedSeconds: elapsedSeconds, source: source)
        return Measurement(elapsedMilliseconds: tracked.elapsedMilliseconds)
    }

    /// 真机基准占位：CI / 模拟器跳过，由 T7.6 专项在 iPhone 12 上执行。
    public static func shouldRunOnCurrentEnvironment(isSimulator: Bool, hasCameraHardware: Bool) -> Bool {
        !isSimulator && hasCameraHardware
    }
}
