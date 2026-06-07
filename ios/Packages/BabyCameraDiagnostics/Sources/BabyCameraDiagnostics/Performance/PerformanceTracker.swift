import Foundation
import os

/// 端侧性能计时与预算校验（design-ios §14 · UX-04）。
/// 相机冷启动 ≤ 800ms · 编辑器打开 ≤ 500ms。
public enum PerformanceTracker {
    public static let cameraColdStartBudgetMs = 800
    public static let editorOpenBudgetMs = 500

    public struct Measurement: Sendable, Equatable {
        public let name: String
        public let elapsedMilliseconds: Int
        public let budgetMilliseconds: Int

        public var withinBudget: Bool {
            elapsedMilliseconds <= budgetMilliseconds
        }

        public var statusLabel: String {
            withinBudget ? "PASS" : "FAIL"
        }
    }

    private static let log = Logger(subsystem: "com.babycamera", category: "Performance")

    /// 记录相机冷启动耗时（授权通过 → 首帧预览）。
    @discardableResult
    public static func recordCameraColdStart(
        elapsedSeconds: TimeInterval,
        source: String = "camera_tab"
    ) -> Measurement {
        let measurement = makeMeasurement(
            name: "camera_cold_start",
            elapsedSeconds: elapsedSeconds,
            budgetMilliseconds: cameraColdStartBudgetMs
        )
        emit(measurement, source: source)
        AnalyticsFeatureTracks.trackCameraOpen(elapsedMs: measurement.elapsedMilliseconds)
        return measurement
    }

    /// 记录编辑器打开耗时（触发打开 → UI 可交互）。
    @discardableResult
    public static func recordEditorOpen(
        elapsedSeconds: TimeInterval,
        source: String
    ) -> Measurement {
        let measurement = makeMeasurement(
            name: "editor_open",
            elapsedSeconds: elapsedSeconds,
            budgetMilliseconds: editorOpenBudgetMs
        )
        emit(measurement, source: source)
        AnalyticsFeatureTracks.trackEditorOpen(
            source: source,
            elapsedMs: measurement.elapsedMilliseconds
        )
        return measurement
    }

    public static func formattedLogLine(
        _ measurement: Measurement,
        source: String
    ) -> String {
        "[Performance] \(measurement.name) source=\(source) elapsed=\(measurement.elapsedMilliseconds)ms budget=\(measurement.budgetMilliseconds)ms \(measurement.statusLabel)"
    }

    private static func makeMeasurement(
        name: String,
        elapsedSeconds: TimeInterval,
        budgetMilliseconds: Int
    ) -> Measurement {
        Measurement(
            name: name,
            elapsedMilliseconds: milliseconds(from: elapsedSeconds),
            budgetMilliseconds: budgetMilliseconds
        )
    }

    private static func emit(_ measurement: Measurement, source: String) {
        let line = formattedLogLine(measurement, source: source)
        #if DEBUG
        print(line)
        #endif
        log.info("\(line, privacy: .public)")
    }

    private static func milliseconds(from seconds: TimeInterval) -> Int {
        Int((seconds * 1000).rounded())
    }
}
