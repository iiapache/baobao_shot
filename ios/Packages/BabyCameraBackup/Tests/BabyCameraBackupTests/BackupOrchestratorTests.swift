import XCTest
@testable import BabyCameraBackup

final class BackupOrchestratorTests: XCTestCase {
    private var photoSource: MockBackupPhotoSource!
    private var dedupStore: InMemoryBackupDedupStore!
    private var orchestrator: BackupOrchestrator!

    override func setUp() {
        super.setUp()
        photoSource = MockBackupPhotoSource()
        dedupStore = InMemoryBackupDedupStore()
        orchestrator = BackupOrchestrator(
            photoSource: photoSource,
            dedupStore: dedupStore,
            deviceMonitor: MockBackupDeviceMonitor(snapshot: makeEligibleDevice())
        )
    }

    private func makeOrchestrator(snapshot: BackupDeviceSnapshot) -> BackupOrchestrator {
        BackupOrchestrator(
            photoSource: photoSource,
            dedupStore: dedupStore,
            deviceMonitor: MockBackupDeviceMonitor(snapshot: snapshot)
        )
    }

    func testAutomaticBackupRunsWhenTriggerConditionsMet() async throws {
        photoSource.photos = [
            makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100),
        ]
        let provider = MockBackupProvider(kind: .iCloud)

        let report = try await orchestrator.runBackup(
            trigger: .automatic,
            providers: [provider],
            preferences: BackupAutoBackupPreferences()
        )

        XCTAssertEqual(report.trigger, .automatic)
        XCTAssertEqual(report.totalUploadedCount, 1)
        XCTAssertEqual(provider.uploadedItems.map(\.sha256), ["hash-a"])
    }

    func testAutomaticBackupRejectedWhenNotOnWiFi() async throws {
        orchestrator = makeOrchestrator(
            snapshot: makeEligibleDevice(isOnWiFi: false)
        )

        do {
            _ = try await orchestrator.runBackup(
                trigger: .automatic,
                providers: [MockBackupProvider(kind: .iCloud)],
                preferences: BackupAutoBackupPreferences()
            )
            XCTFail("Expected triggerConditionsNotMet")
        } catch let error as BackupOrchestratorError {
            XCTAssertEqual(
                error,
                .triggerConditionsNotMet([.notOnWiFi])
            )
        }
    }

    func testAutomaticBackupRejectedWhenNotCharging() async throws {
        orchestrator = makeOrchestrator(
            snapshot: makeEligibleDevice(isCharging: false)
        )

        do {
            _ = try await orchestrator.runBackup(
                trigger: .automatic,
                providers: [MockBackupProvider(kind: .iCloud)],
                preferences: BackupAutoBackupPreferences()
            )
            XCTFail("Expected triggerConditionsNotMet")
        } catch let error as BackupOrchestratorError {
            XCTAssertEqual(
                error,
                .triggerConditionsNotMet([.notCharging])
            )
        }
    }

    func testAutomaticBackupRejectedWhenBatteryTooLow() async throws {
        orchestrator = makeOrchestrator(
            snapshot: makeEligibleDevice(batteryLevel: 0.25)
        )

        do {
            _ = try await orchestrator.runBackup(
                trigger: .automatic,
                providers: [MockBackupProvider(kind: .iCloud)],
                preferences: BackupAutoBackupPreferences()
            )
            XCTFail("Expected triggerConditionsNotMet")
        } catch let error as BackupOrchestratorError {
            XCTAssertEqual(
                error,
                .triggerConditionsNotMet([.batteryTooLow(current: 0.25, required: 0.30)])
            )
        }
    }

    func testManualBackupBypassesTriggerConditions() async throws {
        orchestrator = makeOrchestrator(
            snapshot: BackupDeviceSnapshot(
                isOnWiFi: false,
                isCharging: false,
                batteryLevel: 0.05
            )
        )
        photoSource.photos = [
            makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100),
        ]
        let provider = MockBackupProvider(kind: .photos)

        let report = try await orchestrator.runBackup(
            trigger: .manual,
            providers: [provider],
            preferences: BackupAutoBackupPreferences()
        )

        XCTAssertEqual(report.trigger, .manual)
        XCTAssertEqual(report.totalUploadedCount, 1)
    }

    func testIncrementalDedupSkipsAlreadyBackedUpSHA256() async throws {
        await dedupStore.markBackedUp(sha256: "hash-b", provider: .iCloud)
        photoSource.photos = [
            makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100),
            makeCandidate(id: "p2", sha256: "hash-b", updatedAt: 200),
            makeCandidate(id: "p3", sha256: "hash-c", updatedAt: 300),
        ]
        let provider = MockBackupProvider(kind: .iCloud)

        let report = try await orchestrator.runBackup(
            trigger: .manual,
            providers: [provider],
            preferences: BackupAutoBackupPreferences()
        )

        XCTAssertEqual(report.providerResults[0].uploadedCount, 2)
        XCTAssertEqual(report.providerResults[0].skippedCount, 1)
        XCTAssertEqual(provider.uploadedItems.map(\.sha256), ["hash-a", "hash-c"])
    }

    func testSecondRunUploadsOnlyNewSHA256() async throws {
        photoSource.photos = [
            makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100),
            makeCandidate(id: "p2", sha256: "hash-b", updatedAt: 200),
        ]
        let provider = MockBackupProvider(kind: .iCloud)

        _ = try await orchestrator.runBackup(
            trigger: .manual,
            providers: [provider],
            preferences: BackupAutoBackupPreferences()
        )

        photoSource.photos.append(
            makeCandidate(id: "p3", sha256: "hash-c", updatedAt: 300)
        )

        let secondReport = try await orchestrator.runBackup(
            trigger: .manual,
            providers: [provider],
            preferences: BackupAutoBackupPreferences()
        )

        XCTAssertEqual(secondReport.providerResults[0].uploadedCount, 1)
        XCTAssertEqual(secondReport.providerResults[0].uploadedSHA256s, ["hash-c"])
        XCTAssertEqual(provider.uploadedItems.map(\.sha256), ["hash-a", "hash-b", "hash-c"])
    }

    func testRunsAcrossMultipleProvidersWithPerProviderDedup() async throws {
        await dedupStore.markBackedUp(sha256: "hash-a", provider: .photos)
        photoSource.photos = [
            makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100),
            makeCandidate(id: "p2", sha256: "hash-b", updatedAt: 200),
        ]
        let iCloud = MockBackupProvider(kind: .iCloud)
        let photos = MockBackupProvider(kind: .photos)

        let report = try await orchestrator.runBackup(
            trigger: .manual,
            providers: [iCloud, photos],
            preferences: BackupAutoBackupPreferences()
        )

        XCTAssertEqual(report.providerResults.count, 2)
        XCTAssertEqual(iCloud.uploadedItems.map(\.sha256), ["hash-a", "hash-b"])
        XCTAssertEqual(photos.uploadedItems.map(\.sha256), ["hash-b"])
    }

    func testEvaluateAutomaticTriggerDelegatesToDeviceMonitor() async {
        orchestrator = makeOrchestrator(
            snapshot: makeEligibleDevice(isOnWiFi: false, isCharging: false, batteryLevel: 0.10)
        )

        let evaluation = await orchestrator.evaluateAutomaticTrigger(
            preferences: BackupAutoBackupPreferences()
        )

        XCTAssertFalse(evaluation.canRun)
        XCTAssertEqual(evaluation.blockReasons.count, 3)
    }

    func testThrowsWhenNoProvidersConfigured() async {
        do {
            _ = try await orchestrator.runBackup(
                trigger: .manual,
                providers: [],
                preferences: BackupAutoBackupPreferences()
            )
            XCTFail("Expected noProvidersConfigured")
        } catch let error as BackupOrchestratorError {
            XCTAssertEqual(error, .noProvidersConfigured)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
