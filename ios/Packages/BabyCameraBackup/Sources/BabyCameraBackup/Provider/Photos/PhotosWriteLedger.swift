import Foundation

public protocol PhotosWriteLedger: Sendable {
    func record(item: BackupRemoteItem, byteSize: Int64) async
    func page(after cursor: String?, limit: Int) async -> BackupPage
    func totalUsedBytes() async -> Int64
    func clear() async
}

public actor InMemoryPhotosWriteLedger: PhotosWriteLedger {
    private struct Entry: Sendable {
        let item: BackupRemoteItem
        let byteSize: Int64
    }

    private var entries: [Entry] = []

    public init() {}

    public func record(item: BackupRemoteItem, byteSize: Int64) async {
        entries.append(Entry(item: item, byteSize: byteSize))
    }

    public func page(after cursor: String?, limit: Int) async -> BackupPage {
        let sorted = entries.map(\.item).sorted { $0.remoteId < $1.remoteId }
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

        let slice = Array(sorted[startIndex..<endIndex])
        let nextCursor = endIndex < sorted.count ? slice.last?.remoteId : nil
        return BackupPage(items: slice, nextCursor: nextCursor)
    }

    public func totalUsedBytes() async -> Int64 {
        entries.reduce(0) { $0 + $1.byteSize }
    }

    public func clear() async {
        entries = []
    }
}
