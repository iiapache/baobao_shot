import Foundation
@testable import BabyCameraBackup

struct MockBackupDeviceMonitor: BackupDeviceConditionMonitoring {
    var snapshot: BackupDeviceSnapshot

    init(snapshot: BackupDeviceSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() async -> BackupDeviceSnapshot {
        snapshot
    }
}

final class MockBackupPhotoSource: BackupPhotoSource, @unchecked Sendable {
    var photos: [BackupPhotoCandidate] = []
    var error: Error?

    func pendingPhotos() async throws -> [BackupPhotoCandidate] {
        if let error { throw error }
        return photos
    }
}

final class MockBackupProvider: BackupProvider, @unchecked Sendable {
    let kind: BackupKind
    private(set) var uploadedItems: [BackupItem] = []
    var uploadError: Error?
    var authorizeCallCount = 0

    init(kind: BackupKind) {
        self.kind = kind
    }

    func authorize() async throws {
        authorizeCallCount += 1
    }

    func quota() async throws -> BackupQuota {
        BackupQuota(usedBytes: 0, totalBytes: nil)
    }

    func upload(_ item: BackupItem) async throws -> BackupReceipt {
        if let uploadError { throw uploadError }
        uploadedItems.append(item)
        return BackupReceipt(
            remoteId: "remote-\(item.photoId)",
            sha256: item.sha256,
            uploadedAt: 1_700_000_000_000
        )
    }

    func list(after cursor: String?) async throws -> BackupPage {
        BackupPage(items: [])
    }

    func revoke() async throws {}
}
func makeEligibleDevice(
    isOnWiFi: Bool = true,
    isCharging: Bool = true,
    batteryLevel: Double = 0.85
) -> BackupDeviceSnapshot {
    BackupDeviceSnapshot(
        isOnWiFi: isOnWiFi,
        isCharging: isCharging,
        batteryLevel: batteryLevel
    )
}

func makeCandidate(
    id: String,
    sha256: String,
    updatedAt: Int64
) -> BackupPhotoCandidate {
    BackupPhotoCandidate(
        photoId: id,
        sha256: sha256,
        filePath: "/tmp/\(id).heic",
        updatedAt: updatedAt
    )
}
