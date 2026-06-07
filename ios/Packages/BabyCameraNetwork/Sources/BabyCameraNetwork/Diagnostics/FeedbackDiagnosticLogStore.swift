import Foundation

/// 环形缓冲，供客服反馈附件读取最近网络诊断日志（T6.13）。
public enum FeedbackDiagnosticLogStore {
    public static let defaultCapacity = 200

    private static let lock = NSLock()
    private static var messages: [String] = []
    private static var capacity = defaultCapacity

    public static func configure(capacity: Int) {
        lock.lock()
        defer { lock.unlock() }
        Self.capacity = max(1, capacity)
        trimIfNeeded()
    }

    public static func append(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        messages.append(message)
        trimIfNeeded()
    }

    public static func recentLines(limit: Int) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard limit > 0 else { return [] }
        return Array(messages.suffix(limit))
    }

    public static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        messages.removeAll(keepingCapacity: true)
        capacity = defaultCapacity
    }

    private static func trimIfNeeded() {
        if messages.count > capacity {
            messages.removeFirst(messages.count - capacity)
        }
    }
}
