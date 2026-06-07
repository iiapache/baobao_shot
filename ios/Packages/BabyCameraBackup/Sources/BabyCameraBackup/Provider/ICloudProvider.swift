import Foundation

public enum ICloudProviderError: Error, Sendable, Equatable {
    case iCloudUnavailable(CloudKitAccountStatus)
    case localFileNotFound(path: String)
    case cloudKit(CloudKitPrivateDatabaseError)
}

/// iCloud 备份 Provider：走 CloudKit Private Database，不占用 iCloud Drive 用户可见目录。
public struct ICloudProvider: BackupProvider, Sendable {
    public let kind: BackupKind = .iCloud

    private let database: any CloudKitPrivateDatabaseProviding
    private let clock: any BackupClock
    private let listPageSize: Int

    public init(
        database: any CloudKitPrivateDatabaseProviding,
        clock: any BackupClock = SystemBackupClock(),
        listPageSize: Int = 100
    ) {
        self.database = database
        self.clock = clock
        self.listPageSize = listPageSize
    }

    public static func live(
        containerIdentifier: String = "iCloud.app.babycamera",
        clock: any BackupClock = SystemBackupClock()
    ) -> ICloudProvider {
        ICloudProvider(
            database: LiveCloudKitPrivateDatabase(
                containerIdentifier: containerIdentifier,
                clock: clock
            ),
            clock: clock
        )
    }

    public func authorize() async throws {
        let status = try await database.accountStatus()
        guard status == .available else {
            throw ICloudProviderError.iCloudUnavailable(status)
        }
    }

    public func quota() async throws -> BackupQuota {
        try await authorize()

        var usedBytes: Int64 = 0
        var cursor: String?

        repeat {
            let page = try await database.fetchRecords(after: cursor, limit: listPageSize)
            usedBytes += page.records.reduce(into: Int64(0)) { partial, record in
                partial += record.byteSize
            }
            cursor = page.nextCursor
        } while cursor != nil

        return BackupQuota(usedBytes: usedBytes, totalBytes: nil)
    }

    public func upload(_ item: BackupItem) async throws -> BackupReceipt {
        try await authorize()

        let fileURL = URL(fileURLWithPath: item.filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ICloudProviderError.localFileNotFound(path: item.filePath)
        }

        let input = CloudKitBackupRecordInput(
            photoId: item.photoId,
            sha256: item.sha256,
            mimeType: item.mimeType,
            byteSize: item.byteSize,
            updatedAt: item.updatedAt,
            fileURL: fileURL
        )

        do {
            let output = try await database.saveRecord(input)
            return BackupReceipt(
                remoteId: output.recordID,
                sha256: output.sha256,
                uploadedAt: clock.nowUnixMillis()
            )
        } catch let error as CloudKitPrivateDatabaseError {
            throw ICloudProviderError.cloudKit(error)
        }
    }

    public func list(after cursor: String?) async throws -> BackupPage {
        try await authorize()

        do {
            let page = try await database.fetchRecords(after: cursor, limit: listPageSize)
            let items = page.records.map {
                BackupRemoteItem(remoteId: $0.recordID, sha256: $0.sha256)
            }
            return BackupPage(items: items, nextCursor: page.nextCursor)
        } catch let error as CloudKitPrivateDatabaseError {
            throw ICloudProviderError.cloudKit(error)
        }
    }

    public func revoke() async throws {
        do {
            try await database.deleteAllBackupRecords()
        } catch let error as CloudKitPrivateDatabaseError {
            throw ICloudProviderError.cloudKit(error)
        }
    }
}
