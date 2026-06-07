import CloudKit
import Foundation

/// 基于 CloudKit Private Database 的 live 实现；数据存于用户不可见的私有库。
public struct LiveCloudKitPrivateDatabase: CloudKitPrivateDatabaseProviding, Sendable {
    private let container: CKContainer
    private let database: CKDatabase
    private let clock: any BackupClock

    public init(
        containerIdentifier: String = "iCloud.app.babycamera",
        clock: any BackupClock = SystemBackupClock()
    ) {
        let container = CKContainer(identifier: containerIdentifier)
        self.container = container
        self.database = container.privateCloudDatabase
        self.clock = clock
    }

    public func accountStatus() async throws -> CloudKitAccountStatus {
        let status = try await container.accountStatus()
        return mapAccountStatus(status)
    }

    public func saveRecord(_ input: CloudKitBackupRecordInput) async throws -> CloudKitBackupRecordOutput {
        let recordID = CKRecord.ID(recordName: ICloudBackupRecordSchema.recordName(for: input.photoId))
        let record = CKRecord(recordType: ICloudBackupRecordSchema.recordType, recordID: recordID)
        record[ICloudBackupRecordSchema.photoId] = input.photoId as CKRecordValue
        record[ICloudBackupRecordSchema.sha256] = input.sha256 as CKRecordValue
        record[ICloudBackupRecordSchema.mimeType] = input.mimeType as CKRecordValue
        record[ICloudBackupRecordSchema.byteSize] = NSNumber(value: input.byteSize)
        record[ICloudBackupRecordSchema.updatedAt] = NSNumber(value: input.updatedAt)
        record[ICloudBackupRecordSchema.asset] = CKAsset(fileURL: input.fileURL)

        do {
            let saved = try await database.save(record)
            let uploadedAt = clock.nowUnixMillis()
            return CloudKitBackupRecordOutput(
                recordID: saved.recordID.recordName,
                photoId: input.photoId,
                sha256: input.sha256,
                byteSize: input.byteSize,
                uploadedAt: uploadedAt
            )
        } catch {
            throw CloudKitPrivateDatabaseError.saveFailed(error.localizedDescription)
        }
    }

    public func fetchRecords(after cursor: String?, limit: Int) async throws -> CloudKitBackupRecordPage {
        let predicate: NSPredicate
        if let cursor {
            predicate = NSPredicate(
                format: "%K > %@",
                ICloudBackupRecordSchema.photoId,
                cursor
            )
        } else {
            predicate = NSPredicate(value: true)
        }

        let query = CKQuery(
            recordType: ICloudBackupRecordSchema.recordType,
            predicate: predicate
        )
        query.sortDescriptors = [
            NSSortDescriptor(key: ICloudBackupRecordSchema.photoId, ascending: true),
        ]

        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                inZoneWith: nil,
                desiredKeys: [
                    ICloudBackupRecordSchema.sha256,
                    ICloudBackupRecordSchema.byteSize,
                    ICloudBackupRecordSchema.photoId,
                ],
                resultsLimit: limit + 1
            )

            var summaries: [CloudKitBackupRecordSummary] = []
            summaries.reserveCapacity(limit + 1)

            for (_, result) in matchResults {
                guard case let .success(record) = result else { continue }
                guard
                    let photoId = record[ICloudBackupRecordSchema.photoId] as? String,
                    let sha256 = record[ICloudBackupRecordSchema.sha256] as? String,
                    let byteSizeNumber = record[ICloudBackupRecordSchema.byteSize] as? NSNumber
                else {
                    continue
                }
                summaries.append(
                    CloudKitBackupRecordSummary(
                        recordID: record.recordID.recordName,
                        photoId: photoId,
                        sha256: sha256,
                        byteSize: byteSizeNumber.int64Value
                    )
                )
            }

            summaries.sort { $0.photoId < $1.photoId }

            let pageRecords: [CloudKitBackupRecordSummary]
            let nextCursor: String?
            if summaries.count > limit {
                pageRecords = Array(summaries.prefix(limit))
                nextCursor = pageRecords.last?.photoId
            } else {
                pageRecords = summaries
                nextCursor = nil
            }

            return CloudKitBackupRecordPage(records: pageRecords, nextCursor: nextCursor)
        } catch {
            throw CloudKitPrivateDatabaseError.fetchFailed(error.localizedDescription)
        }
    }

    public func deleteAllBackupRecords() async throws {
        let query = CKQuery(
            recordType: ICloudBackupRecordSchema.recordType,
            predicate: NSPredicate(value: true)
        )

        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                inZoneWith: nil,
                desiredKeys: [],
                resultsLimit: CKQueryOperation.maximumResults
            )

            let recordIDs = matchResults.compactMap { recordID, result -> CKRecord.ID? in
                guard case .success = result else { return nil }
                return recordID
            }

            guard !recordIDs.isEmpty else { return }

            _ = try await database.modifyRecords(saving: [], deleting: recordIDs)
        } catch {
            throw CloudKitPrivateDatabaseError.deleteFailed(error.localizedDescription)
        }
    }

    private func mapAccountStatus(_ status: CKAccountStatus) -> CloudKitAccountStatus {
        switch status {
        case .available:
            return .available
        case .noAccount:
            return .noAccount
        case .restricted:
            return .restricted
        case .couldNotDetermine:
            return .couldNotDetermine
        case .temporarilyUnavailable:
            return .temporarilyUnavailable
        @unknown default:
            return .couldNotDetermine
        }
    }
}
