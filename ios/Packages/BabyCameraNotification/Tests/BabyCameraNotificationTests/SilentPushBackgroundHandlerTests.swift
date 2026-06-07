import XCTest
@testable import BabyCameraNotification

final class SilentPushBackgroundHandlerTests: XCTestCase {
    func testSilentAIDoneSchedulesBackgroundRefresh() async {
        let refreshScheduler = MockBackgroundRefreshScheduler()
        let pendingStore = InMemoryPendingAIRefreshStore()
        let clock = MockNotificationClock()
        let handler = SilentPushBackgroundHandler(
            refreshScheduler: refreshScheduler,
            pendingStore: pendingStore,
            milestoneFallback: MilestoneFallbackCoordinator(scheduler: MockLocalNotificationScheduler()),
            clock: clock
        )

        let outcome = await handler.handle(userInfo: [
            "category": "AI_DONE",
            "taskId": "tsk_bg_001",
            "state": "succeeded",
            "resultUrl": "https://cdn.example/bg.heic",
            "aps": ["content-available": 1],
        ])

        guard case let .scheduledBackgroundRefresh(payload) = outcome else {
            return XCTFail("expected scheduledBackgroundRefresh, got \(outcome)")
        }
        XCTAssertEqual(payload.taskId, "tsk_bg_001")
        XCTAssertEqual(refreshScheduler.submittedRequests.count, 1)
        XCTAssertEqual(
            refreshScheduler.submittedRequests.first?.identifier,
            AIResultBackgroundRefreshTask.identifier
        )

        let pending = await pendingStore.dequeueAll()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.taskId, "tsk_bg_001")
    }

    func testSilentAIDoneReportsScheduleFailure() async {
        let refreshScheduler = MockBackgroundRefreshScheduler()
        refreshScheduler.submitResult = false
        let handler = SilentPushBackgroundHandler(
            refreshScheduler: refreshScheduler,
            pendingStore: InMemoryPendingAIRefreshStore()
        )

        let outcome = await handler.handle(userInfo: [
            "category": "AI_DONE",
            "taskId": "tsk_fail",
            "state": "succeeded",
            "aps": ["content-available": 1],
        ])

        guard case let .failedToSchedule(payload) = outcome else {
            return XCTFail("expected failedToSchedule")
        }
        XCTAssertEqual(payload.taskId, "tsk_fail")
    }

    func testMilestonePushTriggersFallback() async {
        let mockScheduler = MockLocalNotificationScheduler()
        mockScheduler.pending = [
            UNNotificationRequest(
                identifier: "milestone.baby-1.ms_full_moon",
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
        ]

        let handler = SilentPushBackgroundHandler(
            refreshScheduler: MockBackgroundRefreshScheduler(),
            pendingStore: InMemoryPendingAIRefreshStore(),
            milestoneFallback: MilestoneFallbackCoordinator(scheduler: mockScheduler)
        )

        let outcome = await handler.handle(userInfo: [
            "category": "MILESTONE",
            "babyId": "baby-1",
            "milestoneId": "ms_full_moon",
            "aps": ["alert": ["title": "里程碑提醒"]],
        ])

        guard case let .milestoneFallback(result) = outcome else {
            return XCTFail("expected milestoneFallback")
        }
        XCTAssertEqual(result.removedLocalNotificationIdentifiers, ["milestone.baby-1.ms_full_moon"])
    }

    func testBackgroundRefreshExecutorRunsDequeuedPayloads() async {
        let refreshScheduler = MockBackgroundRefreshScheduler()
        let pendingStore = InMemoryPendingAIRefreshStore()
        let executor = MockAIResultBackgroundExecutor()

        AIResultBackgroundRefreshRegistrar.register(
            scheduler: refreshScheduler,
            pendingStore: pendingStore,
            executor: executor
        )

        await pendingStore.enqueue(
            RemotePushPayload(
                category: .aiDone,
                isSilent: true,
                taskId: "tsk_exec",
                state: "succeeded",
                resultUrl: "https://cdn.example/exec.heic"
            )
        )

        let success = await refreshScheduler.handler?()
        XCTAssertEqual(success, true)
        XCTAssertEqual(executor.executedPayloads.count, 1)
        XCTAssertEqual(executor.executedPayloads.first?.first?.taskId, "tsk_exec")
    }

    func testIgnoresNonSilentNonMilestonePush() async {
        let handler = SilentPushBackgroundHandler(
            refreshScheduler: MockBackgroundRefreshScheduler(),
            pendingStore: InMemoryPendingAIRefreshStore()
        )

        let outcome = await handler.handle(userInfo: [
            "category": "FAMILY_ACTIVITY",
            "aps": ["alert": ["title": "家人动态"]],
        ])

        XCTAssertEqual(outcome, .ignored)
    }
}
