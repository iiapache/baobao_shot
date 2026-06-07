import XCTest
@testable import BabyCameraAIPlay

final class AITaskOutcomeMapperTests: XCTestCase {
    func testModelFailedPresentation() {
        let snapshot = AITaskSnapshot(
            taskId: "tsk_failed_001",
            phase: .failed,
            serverState: "failed",
            costCredits: 8,
            balanceAfter: 100,
            failureReason: "模型服务暂时不可用",
            updatedAt: Date()
        )

        let presentation = AITaskOutcomeMapper.presentation(for: snapshot)

        XCTAssertEqual(presentation?.kind, .modelFailed)
        XCTAssertEqual(presentation?.title, "生成失败")
        XCTAssertEqual(presentation?.message, "模型服务暂时不可用")
        XCTAssertFalse(presentation?.canAppeal == true)
        XCTAssertEqual(presentation?.creditRefund?.refundedCredits, 8)
        XCTAssertEqual(presentation?.creditRefund?.balanceAfter, 100)
        XCTAssertEqual(
            presentation?.creditRefund?.message,
            "已退还 8 积分，当前余额 100 积分"
        )
    }

    func testRejectedPresentationWithAppealEntry() {
        let snapshot = AITaskSnapshot(
            taskId: "tsk_rejected_001",
            phase: .rejected,
            serverState: "rejected",
            costCredits: 8,
            balanceAfter: 100
        )

        let presentation = AITaskOutcomeMapper.presentation(for: snapshot)

        XCTAssertEqual(presentation?.kind, .rejected)
        XCTAssertEqual(presentation?.title, "内容未通过审核")
        XCTAssertEqual(presentation?.message, "该内容不符合社区规范")
        XCTAssertTrue(presentation?.canAppeal == true)
        XCTAssertNotNil(presentation?.creditRefund)
    }

    func testRefundedCreditsDetectedOnTerminalFailure() {
        let snapshot = AITaskSnapshot(
            taskId: "tsk_refund_001",
            phase: .failed,
            serverState: "failed",
            costCredits: 12,
            balanceAfter: 88
        )

        let refund = AITaskOutcomeMapper.creditRefund(from: snapshot)

        XCTAssertEqual(refund?.refundedCredits, 12)
        XCTAssertEqual(refund?.balanceAfter, 88)
    }

    func testModelFailedIntermediateStateMapsToRunning() {
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "model_failed"), .running)
        XCTAssertFalse(AITaskPhaseMapper.isTerminalServerState("model_failed"))
    }

    func testAppealedPresentation() {
        let snapshot = AITaskSnapshot(
            taskId: "tsk_appealed_001",
            phase: .appealed,
            serverState: "appealed",
            costCredits: 8,
            balanceAfter: 100
        )

        let presentation = AITaskOutcomeMapper.presentation(for: snapshot)

        XCTAssertEqual(presentation?.kind, .appealed)
        XCTAssertEqual(presentation?.title, "申诉已提交")
        XCTAssertFalse(presentation?.canAppeal == true)
    }
}
