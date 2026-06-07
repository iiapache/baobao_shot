import XCTest
@testable import BabyCameraBackup

final class BackupQueueTests: XCTestCase {
    private var photoSource: MockBackupPhotoSource!
    private var dedupStore: InMemoryBackupDedupStore!
    private var orchestrator: BackupOrchestrator!
    private var persistence: InMemoryBackupQueueStore!
    private var networkMonitor: MockBackupNetworkMonitor!
    private var alerter: RecordingBackupConsecutiveFailureAlerter!
    private var sleeper: RecordingBackupQueueSleeper!
    private var clock: ControllableBackupClock!
    private var queue: BackupQueue!

    override func setUp() {
        super.setUp()
        photoSource = MockBackupPhotoSource()
        dedupStore = InMemoryBackupDedupStore()
        orchestrator = BackupOrchestrator(
            photoSource: photoSource,
            dedupStore: dedupStore,
            deviceMonitor: MockBackupDeviceMonitor(snapshot: makeEligibleDevice())
        )
        persistence = InMemoryBackupQueueStore()
        networkMonitor = MockBackupNetworkMonitor()
        alerter = RecordingBackupConsecutiveFailureAlerter()
        sleeper = RecordingBackupQueueSleeper()
        clock = ControllableBackupClock()
        queue = makeQueue()
    }

    private func makeQueue(
        provider: MockBackupProvider = MockBackupProvider(kind: .iCloud),
        configuration: BackupQueueConfiguration = BackupQueueConfiguration()
    ) -> BackupQueue {
        BackupQueue(
            orchestrator: orchestrator,
            persistence: persistence,
            providerResolver: StaticBackupProviderResolver(providers: [provider]),
            networkMonitor: networkMonitor,
            alertPresenter: alerter,
            clock: clock,
            sleeper: sleeper,
            configuration: configuration
        )
    }

    func testEnqueuePersistsAcrossReloadedQueue() async throws {
        networkMonitor = MockBackupNetworkMonitor(
            snapshot: BackupNetworkSnapshot(isOnline: false, isOnWiFi: false)
        )
        queue = makeQueue()

        _ = try await queue.enqueue(
            trigger: .manual,
            providerKinds: [.iCloud]
        )

        let reopened = makeQueue()
        let tasks = try await reopened.snapshot()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].trigger, .manual)
        XCTAssertEqual(tasks[0].providerKinds, [.iCloud])
    }

    func testSuccessfulRunRemovesTaskAndResetsConsecutiveFailures() async throws {
        photoSource.photos = [makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100)]
        let provider = MockBackupProvider(kind: .iCloud)
        queue = makeQueue(provider: provider)

        _ = try await persistence.saveState(
            BackupQueuePersistedState(tasks: [], consecutiveFailureCount: 2)
        )
        queue = makeQueue(provider: provider)

        _ = try await queue.enqueue(trigger: .manual, providerKinds: [.iCloud])
        await queue.start()

        XCTAssertEqual(try await queue.pendingTaskCount, 0)
        XCTAssertEqual(try await queue.consecutiveFailureCount, 0)
        XCTAssertEqual(provider.uploadedItems.map(\.sha256), ["hash-a"])
    }

    func testFailureRetriesWithExponentialBackoffBeforeNextRound() async throws {
        let provider = MockBackupProvider(kind: .iCloud)
        provider.uploadError = URLError(.cannotConnectToHost)
        queue = makeQueue(provider: provider)

        _ = try await queue.enqueue(trigger: .manual, providerKinds: [.iCloud])
        await queue.processNow()

        XCTAssertEqual(sleeper.sleptSeconds, [1, 2, 4])
        XCTAssertEqual(try await queue.pendingTaskCount, 1)
        XCTAssertEqual(try await queue.consecutiveFailureCount, 1)
        let task = try await queue.snapshot()[0]
        XCTAssertEqual(task.attemptCount, 0)
        XCTAssertNotNil(task.nextRetryAt)
    }

    func testThreeConsecutiveFailureRoundsTriggerAlert() async throws {
        let provider = MockBackupProvider(kind: .iCloud)
        provider.uploadError = URLError(.cannotConnectToHost)
        queue = makeQueue(provider: provider)

        _ = try await queue.enqueue(trigger: .manual, providerKinds: [.iCloud])
        for _ in 0..<3 {
            await queue.processNow()
            clock.advance(bySeconds: 10)
        }

        XCTAssertEqual(alerter.alertCounts, [3])
        XCTAssertEqual(try await queue.consecutiveFailureCount, 3)
    }

    func testSuccessAfterFailuresResetsConsecutiveCounter() async throws {
        let provider = MockBackupProvider(kind: .iCloud)
        provider.uploadError = URLError(.cannotConnectToHost)
        queue = makeQueue(provider: provider)

        _ = try await queue.enqueue(trigger: .manual, providerKinds: [.iCloud])
        await queue.processNow()
        XCTAssertEqual(try await queue.consecutiveFailureCount, 1)

        provider.uploadError = nil
        photoSource.photos = [makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100)]
        clock.advance(bySeconds: 10)
        await queue.processNow()

        XCTAssertEqual(try await queue.pendingTaskCount, 0)
        XCTAssertEqual(try await queue.consecutiveFailureCount, 0)
        XCTAssertTrue(alerter.alertCounts.isEmpty)
    }

    func testOfflineSkipsProcessingUntilNetworkReturns() async throws {
        photoSource.photos = [makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100)]
        let provider = MockBackupProvider(kind: .iCloud)
        networkMonitor = MockBackupNetworkMonitor(
            snapshot: BackupNetworkSnapshot(isOnline: false, isOnWiFi: false)
        )
        queue = makeQueue(provider: provider)

        _ = try await queue.enqueue(trigger: .manual, providerKinds: [.iCloud])
        await queue.start()

        XCTAssertEqual(try await queue.pendingTaskCount, 1)
        XCTAssertTrue(provider.uploadedItems.isEmpty)

        networkMonitor.setSnapshot(
            BackupNetworkSnapshot(isOnline: true, isOnWiFi: true)
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(try await queue.pendingTaskCount, 0)
        XCTAssertEqual(provider.uploadedItems.map(\.sha256), ["hash-a"])
    }

    func testAutomaticTriggerDeferredWithoutCountingAsFailure() async throws {
        orchestrator = BackupOrchestrator(
            photoSource: photoSource,
            dedupStore: dedupStore,
            deviceMonitor: MockBackupDeviceMonitor(
                snapshot: makeEligibleDevice(isOnWiFi: false)
            )
        )
        let provider = MockBackupProvider(kind: .iCloud)
        queue = makeQueue(provider: provider)

        _ = try await queue.enqueue(trigger: .automatic, providerKinds: [.iCloud])
        await queue.processNow()

        XCTAssertEqual(try await queue.pendingTaskCount, 1)
        XCTAssertEqual(try await queue.consecutiveFailureCount, 0)
        XCTAssertTrue(provider.uploadedItems.isEmpty)
        let task = try await queue.snapshot()[0]
        XCTAssertNotNil(task.nextRetryAt)
    }

    func testUserDefaultsStorePersistsState() async throws {
        let defaults = UserDefaults(suiteName: "BackupQueueTests")!
        defaults.removePersistentDomain(forName: "BackupQueueTests")
        let store = UserDefaultsBackupQueueStore(defaults: defaults)

        let task = BackupQueueTask(
            trigger: .manual,
            providerKinds: [.photos],
            preferences: BackupAutoBackupPreferences(),
            enqueuedAt: 123
        )
        try await store.saveState(
            BackupQueuePersistedState(tasks: [task], consecutiveFailureCount: 1)
        )

        let loaded = try await store.loadState()
        XCTAssertEqual(loaded.tasks.count, 1)
        XCTAssertEqual(loaded.tasks[0].providerKinds, [.photos])
        XCTAssertEqual(loaded.consecutiveFailureCount, 1)
    }
}
