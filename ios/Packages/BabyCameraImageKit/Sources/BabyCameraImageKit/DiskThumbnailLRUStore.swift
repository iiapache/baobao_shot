import CryptoKit
import Foundation

/// 磁盘缩略图 LRU 存储配置。
public struct ThumbnailCacheConfiguration: Sendable {
    public static let defaultMaxTotalBytes: Int64 = 1_073_741_824
    public static let defaultExpirationInterval: TimeInterval = 7 * 24 * 60 * 60

    public let maxTotalBytes: Int64
    public let expirationInterval: TimeInterval
    public let dateProvider: @Sendable () -> Date

    public init(
        maxTotalBytes: Int64 = Self.defaultMaxTotalBytes,
        expirationInterval: TimeInterval = Self.defaultExpirationInterval,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.maxTotalBytes = maxTotalBytes
        self.expirationInterval = expirationInterval
        self.dateProvider = dateProvider
    }

    public static var `default`: Self { Self() }
}

struct DiskCacheEntry: Codable, Equatable {
    let cacheKey: String
    let fileName: String
    let byteCount: Int64
    var lastAccessedAt: Date
    let createdAt: Date
}

/// 磁盘 LRU 缩略图索引与文件管理（7 天过期 + 总容量上限）。
actor DiskThumbnailLRUStore {
    private let directory: URL
    private let indexURL: URL
    private let maxTotalBytes: Int64
    private let expirationInterval: TimeInterval
    private let dateProvider: @Sendable () -> Date

    private var entries: [String: DiskCacheEntry] = [:]
    private var totalBytes: Int64 = 0

    init(
        directory: URL,
        configuration: ThumbnailCacheConfiguration = .default
    ) {
        self.directory = directory
        self.indexURL = directory.appendingPathComponent("index.json")
        self.maxTotalBytes = configuration.maxTotalBytes
        self.expirationInterval = configuration.expirationInterval
        self.dateProvider = configuration.dateProvider

        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        loadIndex()
        reconcileMissingFiles()
        evictExpiredEntries()
        evictUntilWithinLimit()
        persistIndex()
    }

    func data(for key: ThumbnailCacheKey) -> Data? {
        let cacheKey = key.diskCacheKey
        guard var entry = entries[cacheKey] else {
            return nil
        }

        let now = dateProvider()
        if isExpired(entry, at: now) {
            removeEntry(forKey: cacheKey)
            persistIndex()
            return nil
        }

        let fileURL = directory.appendingPathComponent(entry.fileName)
        guard let data = try? Data(contentsOf: fileURL) else {
            removeEntry(forKey: cacheKey)
            persistIndex()
            return nil
        }

        entry.lastAccessedAt = now
        entries[cacheKey] = entry
        persistIndex()
        return data
    }

    func store(_ data: Data, for key: ThumbnailCacheKey) {
        let cacheKey = key.diskCacheKey
        let now = dateProvider()
        let preservedCreatedAt = entries[cacheKey]?.createdAt

        if let existing = entries[cacheKey] {
            removeFile(named: existing.fileName)
            totalBytes -= existing.byteCount
            entries.removeValue(forKey: cacheKey)
        }

        let fileName = key.diskFileName
        let fileURL = directory.appendingPathComponent(fileName)
        try? data.write(to: fileURL, options: .atomic)

        let byteCount = Int64(data.count)
        entries[cacheKey] = DiskCacheEntry(
            cacheKey: cacheKey,
            fileName: fileName,
            byteCount: byteCount,
            lastAccessedAt: now,
            createdAt: preservedCreatedAt ?? now
        )
        totalBytes += byteCount

        evictExpiredEntries()
        evictUntilWithinLimit()
        persistIndex()
    }

    func removeAll() {
        for entry in entries.values {
            removeFile(named: entry.fileName)
        }
        entries.removeAll()
        totalBytes = 0
        persistIndex()
    }

    func entryCount() -> Int {
        entries.count
    }

    func totalStoredBytes() -> Int64 {
        totalBytes
    }

    func containsEntry(for key: ThumbnailCacheKey) -> Bool {
        entries[key.diskCacheKey] != nil
    }

    // MARK: - Private

    private func loadIndex() {
        guard
            let data = try? Data(contentsOf: indexURL),
            let decoded = try? JSONDecoder().decode([DiskCacheEntry].self, from: data)
        else {
            entries = [:]
            totalBytes = 0
            return
        }

        entries = Dictionary(uniqueKeysWithValues: decoded.map { ($0.cacheKey, $0) })
        totalBytes = decoded.reduce(0) { $0 + $1.byteCount }
    }

    private func persistIndex() {
        let payload = Array(entries.values)
        guard let data = try? JSONEncoder().encode(payload) else { return }

        let tempURL = indexURL.appendingPathExtension("tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: indexURL.path) {
                try FileManager.default.removeItem(at: indexURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: indexURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    private func reconcileMissingFiles() {
        var staleKeys: [String] = []
        for (cacheKey, entry) in entries {
            let fileURL = directory.appendingPathComponent(entry.fileName)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                totalBytes -= entry.byteCount
                staleKeys.append(cacheKey)
            }
        }
        for key in staleKeys {
            entries.removeValue(forKey: key)
        }
        if !staleKeys.isEmpty {
            persistIndex()
        }
    }

    private func isExpired(_ entry: DiskCacheEntry, at date: Date) -> Bool {
        date.timeIntervalSince(entry.lastAccessedAt) > expirationInterval
    }

    private func evictExpiredEntries() {
        let now = dateProvider()
        let expiredKeys = entries.values
            .filter { isExpired($0, at: now) }
            .map(\.cacheKey)

        guard !expiredKeys.isEmpty else { return }

        for key in expiredKeys {
            removeEntry(forKey: key)
        }
    }

    private func evictUntilWithinLimit() {
        guard totalBytes > maxTotalBytes else { return }

        let sortedKeys = entries.values
            .sorted { lhs, rhs in
                if lhs.lastAccessedAt == rhs.lastAccessedAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.lastAccessedAt < rhs.lastAccessedAt
            }
            .map(\.cacheKey)

        for key in sortedKeys where totalBytes > maxTotalBytes {
            removeEntry(forKey: key)
        }
    }

    private func removeEntry(forKey cacheKey: String) {
        guard let entry = entries.removeValue(forKey: cacheKey) else { return }
        removeFile(named: entry.fileName)
        totalBytes -= entry.byteCount
    }

    private func removeFile(named fileName: String) {
        let fileURL = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

extension ThumbnailCacheKey {
    var diskCacheKey: String {
        "\(filePath)|\(size.rawValue)"
    }

    var diskFileName: String {
        let digest = SHA256.hash(data: Data(diskCacheKey.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(hex)_\(size.rawValue).jpg"
    }
}
