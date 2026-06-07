import BabyCameraDiagnostics
import Foundation

/// 编辑器打开性能基准（design-ios §14：≤ 500ms）。
public enum EditorOpenBenchmark {
    /// 预算上限（毫秒）。
    public static let budgetMilliseconds: Int = PerformanceTracker.editorOpenBudgetMs

    public struct Measurement: Equatable, Sendable {
        public let elapsedMilliseconds: Int
        public let withinBudget: Bool

        public init(elapsedMilliseconds: Int) {
            self.elapsedMilliseconds = elapsedMilliseconds
            self.withinBudget = elapsedMilliseconds <= EditorOpenBenchmark.budgetMilliseconds
        }
    }

    /// 将秒级耗时转为基准测量结果，并经由 `PerformanceTracker` 输出日志与埋点。
    public static func measure(elapsedSeconds: TimeInterval, source: String = "benchmark") -> Measurement {
        let tracked = PerformanceTracker.recordEditorOpen(elapsedSeconds: elapsedSeconds, source: source)
        return Measurement(elapsedMilliseconds: tracked.elapsedMilliseconds)
    }

    /// 真机基准占位：CI / 模拟器跳过，由 T7.6 专项在 iPhone 12 上执行。
    public static func shouldRunOnCurrentEnvironment(isSimulator: Bool) -> Bool {
        !isSimulator
    }
}
