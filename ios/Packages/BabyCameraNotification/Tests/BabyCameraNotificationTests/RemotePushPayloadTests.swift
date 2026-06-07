import XCTest
@testable import BabyCameraNotification

final class RemotePushPayloadTests: XCTestCase {
    func testParsesSilentAIDonePayload() {
        let payload = RemotePushPayload.from(userInfo: [
            "category": "AI_DONE",
            "taskId": "tsk_001",
            "state": "succeeded",
            "resultUrl": "https://cdn.example/result.heic",
            "thumbnailUrl": "https://cdn.example/thumb.jpg",
            "aps": [
                "content-available": 1,
            ],
        ])

        XCTAssertEqual(payload?.category, .aiDone)
        XCTAssertTrue(payload?.isSilent ?? false)
        XCTAssertTrue(payload?.isSilentAIDone ?? false)
        XCTAssertEqual(payload?.taskId, "tsk_001")
        XCTAssertEqual(payload?.resultUrl, "https://cdn.example/result.heic")
    }

    func testParsesAlertPushAsNonSilent() {
        let payload = RemotePushPayload.from(userInfo: [
            "category": "AI_DONE",
            "taskId": "tsk_alert",
            "aps": [
                "alert": [
                    "title": "AI 任务完成",
                    "body": "作品已生成",
                ],
            ],
        ])

        XCTAssertEqual(payload?.category, .aiDone)
        XCTAssertFalse(payload?.isSilent ?? true)
        XCTAssertFalse(payload?.isSilentAIDone ?? true)
    }

    func testParsesMilestonePayloadFromCustomData() {
        let payload = RemotePushPayload.from(userInfo: [
            "category": "MILESTONE",
            "babyId": "baby-42",
            "milestoneId": "ms_full_moon",
            "templateId": "tpl_full_moon",
            "aps": [
                "category": "MILESTONE",
                "alert": [
                    "title": "里程碑提醒",
                    "body": "满月啦",
                ],
            ],
        ])

        XCTAssertEqual(payload?.category, .milestone)
        XCTAssertEqual(payload?.babyId, "baby-42")
        XCTAssertEqual(payload?.milestoneId, "ms_full_moon")
        XCTAssertEqual(payload?.templateId, "tpl_full_moon")
    }

    func testReturnsNilWhenCategoryMissing() {
        XCTAssertNil(RemotePushPayload.from(userInfo: ["taskId": "tsk_001"]))
    }
}
