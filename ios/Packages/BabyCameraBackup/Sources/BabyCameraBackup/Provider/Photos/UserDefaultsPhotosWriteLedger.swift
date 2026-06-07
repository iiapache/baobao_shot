import Foundation

/// 持久化 Photos 写入台账（仅记录本 App 写入的资产 id，不读取用户相册）。
public actor UserDefaultsPhotosWriteLedger: PhotosWriteLedger {
    private struct Entry: Codable, Sendable {
        let remoteId: String
        let sha256: String
        let byteSize: Int64
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private var entries: [Entry]

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "com.babycamera.backup.photos.ledger"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
    }

    public func record(item: BackupRemoteItem, byteSize: Int64) async {
        entries.removeAll { $0.remoteId == item.remoteId }
        entries.append(Entry(remoteId: item.remoteId, sha256: item.sha256, byteSize: byteSize))
        persist()
    }

    public func page(after cursor: String?, limit: Int) async -> BackupPage {
        let sorted = entries.sorted { $0.remoteId < $1.remoteId }
        let startIndex: Int
        if let cursor,
           let index = sorted.firstIndex(where: { $0.remoteId > cursor }) {
            startIndex = index
        } else if cursor == nil {
            startIndex = 0
        } else {
            return BackupPage(items: [])
        }

        let endIndex = min(startIndex + limit, sorted.count)
        guard startIndex < endIndex else {
            return BackupPage(items: [])
        }

        let slice = sorted[startIndex..<endIndex]
        let items = slice.map { BackupRemoteItem(remoteId: $0.remoteId, sha256: $0.sha256) }
        let nextCursor = endIndex < sorted.count ? items.last?.remoteId : nil
        return BackupPage(items: items, nextCursor: nextCursor)
    }

    public func totalUsedBytes() async -> Int64 {
        entries.reduce(0) { $0 + $1.byteSize }
    }

    public func clear() async {
        entries = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
