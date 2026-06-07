import Foundation

public protocol BaiduPanUploadLedger: Sendable {
    func record(_ file: BaiduPanRemoteFile) async
    func page(after cursor: String?, limit: Int) async -> BackupPage
    func totalUsedBytes() async -> Int64
    func clear() async
}

/// 本地台账：记录已上传 sha256，支持增量 list 与 quota 统计。
public actor InMemoryBaiduPanUploadLedger: BaiduPanUploadLedger {
    private var files: [BaiduPanRemoteFile] = []

    public init(initial: [BaiduPanRemoteFile] = []) {
        files = initial.sorted { $0.remotePath < $1.remotePath }
    }

    public func record(_ file: BaiduPanRemoteFile) async {
        files.removeAll { $0.sha256 == file.sha256 }
        files.append(file)
        files.sort { $0.remotePath < $1.remotePath }
    }

    public func page(after cursor: String?, limit: Int) async -> BackupPage {
        let sorted = files
        let filtered: [BaiduPanRemoteFile]
        if let cursor {
            filtered = sorted.filter { $0.remotePath > cursor }
        } else {
            filtered = sorted
        }

        let pageFiles: [BaiduPanRemoteFile]
        let nextCursor: String?
        if filtered.count > limit {
            pageFiles = Array(filtered.prefix(limit))
            nextCursor = pageFiles.last?.remotePath
        } else {
            pageFiles = filtered
            nextCursor = nil
        }

        let items = pageFiles.map {
            BackupRemoteItem(remoteId: String($0.fsId), sha256: $0.sha256)
        }
        return BackupPage(items: items, nextCursor: nextCursor)
    }

    public func totalUsedBytes() async -> Int64 {
        files.reduce(into: Int64(0)) { $0 += $1.byteSize }
    }

    public func clear() async {
        files.removeAll()
    }
}
