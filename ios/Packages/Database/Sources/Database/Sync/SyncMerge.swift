import Foundation

public enum SyncMerge {
    /// Last-write-wins by `updatedAt` (design-ios §5.3).
    public static func shouldApplyRemote(localUpdatedAt: Int64?, remoteUpdatedAt: Int64) -> Bool {
        guard let localUpdatedAt else { return true }
        return remoteUpdatedAt >= localUpdatedAt
    }
}

enum SyncCursor {
    static let lastSuccessKey = "sync.family_member_baby.lastSuccessAt"

    static func read(from settings: any SettingRepository) async throws -> Int64 {
        guard let value = try await settings.fetch(key: lastSuccessKey)?.value else {
            return 0
        }
        return Int64(value) ?? 0
    }

    static func write(_ timestamp: Int64, to settings: any SettingRepository) async throws {
        try await settings.save(SettingRecord(key: lastSuccessKey, value: String(timestamp)))
    }
}

public enum ISO8601Timestamp {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public static func unixSeconds(from string: String, fallback: Int64 = 0) -> Int64 {
        if let date = formatter.date(from: string) ?? fallbackFormatter.date(from: string) {
            return Int64(date.timeIntervalSince1970)
        }
        return fallback
    }
}
