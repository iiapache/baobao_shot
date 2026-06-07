import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// 进程常驻内存采样结果。
public struct MemoryFootprintSample: Sendable, Equatable {
    public let residentBytes: UInt64
    public let peakBytes: UInt64
    public let budgetBytes: UInt64
    public let capturedAt: Date

    public var exceedsBudget: Bool { peakBytes > budgetBytes }

    public var residentMegabytes: Double {
        Double(residentBytes) / 1_048_576.0
    }

    public var peakMegabytes: Double {
        Double(peakBytes) / 1_048_576.0
    }

    public var budgetMegabytes: Double {
        Double(budgetBytes) / 1_048_576.0
    }
}

/// 可注入的内存读取协议，便于单测。
public protocol MemoryFootprintReading: Sendable {
    func residentSizeBytes() -> UInt64
}

#if DEBUG && canImport(Darwin)
struct MachMemoryFootprintReader: MemoryFootprintReading {
    func residentSizeBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) { infoPointer in
            infoPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    intPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }
}
#endif

#if DEBUG
/// DEBUG 专用内存峰值采样器，对齐 design-ios §14 预算 ≤ 200 MB。
public final class MemoryFootprintSampler: @unchecked Sendable {
    public static let memoryBudgetBytes: UInt64 = 200 * 1_024 * 1_024
    public static let shared = MemoryFootprintSampler()

    private let lock = NSLock()
    private let reader: MemoryFootprintReading
    private var peakBytes: UInt64 = 0

    public init(reader: MemoryFootprintReading = MachMemoryFootprintReader()) {
        self.reader = reader
    }

    public func resetPeak() {
        lock.lock()
        defer { lock.unlock() }
        peakBytes = 0
    }

    @discardableResult
    public func sample(at date: Date = Date()) -> MemoryFootprintSample {
        let resident = reader.residentSizeBytes()

        lock.lock()
        if resident > peakBytes {
            peakBytes = resident
        }
        let peak = peakBytes
        lock.unlock()

        return MemoryFootprintSample(
            residentBytes: resident,
            peakBytes: peak,
            budgetBytes: Self.memoryBudgetBytes,
            capturedAt: date
        )
    }

    public func currentPeakBytes() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return peakBytes
    }

    public func exceedsBudget() -> Bool {
        currentPeakBytes() > Self.memoryBudgetBytes
    }

    public func formattedSummary(sample: MemoryFootprintSample) -> String {
        String(
            format: "resident=%.1f MB peak=%.1f MB budget=%.0f MB %@",
            sample.residentMegabytes,
            sample.peakMegabytes,
            sample.budgetMegabytes,
            sample.exceedsBudget ? "FAIL" : "PASS"
        )
    }
}
#else
/// Release 构建不采样，保留预算常量供 QA 报告引用。
public enum MemoryFootprintSampler {
    public static let memoryBudgetBytes: UInt64 = 200 * 1_024 * 1_024

    public static func currentPeakBytes() -> UInt64 { 0 }
    public static func exceedsBudget() -> Bool { false }
}
#endif
