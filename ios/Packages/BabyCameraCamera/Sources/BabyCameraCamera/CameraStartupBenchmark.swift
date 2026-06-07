import Foundation

/// 相机启动性能基准（design-ios §7.2 / §14：≤ 800ms）。
public enum CameraStartupBenchmark {
    /// 预算上限（毫秒）。
    public static let budgetMilliseconds: Int = 800

    public struct Measurement: Equatable, Sendable {
        public let elapsedMilliseconds: Int
        public let withinBudget: Bool

        public init(elapsedMilliseconds: Int) {
            self.elapsedMilliseconds = elapsedMilliseconds
            self.withinBudget = elapsedMilliseconds <= CameraStartupBenchmark.budgetMilliseconds
        }
    }

    /// 将秒级耗时转为基准测量结果。
    public static func measure(elapsedSeconds: TimeInterval) -> Measurement {
        let ms = Int((elapsedSeconds * 1000).rounded())
        return Measurement(elapsedMilliseconds: ms)
    }

    /// 真机基准占位：CI / 模拟器跳过，由 T7.6 专项在 iPhone 12 上执行。
    public static func shouldRunOnCurrentEnvironment(isSimulator: Bool, hasCameraHardware: Bool) -> Bool {
        !isSimulator && hasCameraHardware
    }
}
