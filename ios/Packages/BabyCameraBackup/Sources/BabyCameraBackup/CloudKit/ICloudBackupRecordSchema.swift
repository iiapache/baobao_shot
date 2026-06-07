import Foundation

/// CloudKit Private Database 记录 schema；不写入 iCloud Drive 用户可见目录。
enum ICloudBackupRecordSchema {
    static let recordType = "BabyCameraBackupPhoto"
    static let photoId = "photoId"
    static let sha256 = "sha256"
    static let mimeType = "mimeType"
    static let byteSize = "byteSize"
    static let updatedAt = "updatedAt"
    static let asset = "asset"

    static func recordName(for photoId: String) -> String {
        "backup-\(photoId)"
    }
}
