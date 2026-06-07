import BabyCameraNetwork
import XCTest
@testable import BabyCameraCredit

final class AITaskCreditBalanceBridgeTests: XCTestCase {
    func testExtractsBalanceAfterEvents() async {
        let (taskStream, taskContinuation) = AsyncStream<AITaskEvent>.makeStream()
        let balanceStream = AITaskCreditBalanceBridge.balanceEvents(from: taskStream)

        let expectation = expectation(description: "balance event")
        let consumer = Task {
            var events: [AITaskBalanceEvent] = []
            for await event in balanceStream {
                events.append(event)
            }
            XCTAssertEqual(events.count, 1)
            XCTAssertEqual(events[0].taskId, "tsk_001")
            XCTAssertEqual(events[0].balanceAfter, 92)
            expectation.fulfill()
        }

        taskContinuation.yield(
            AITaskEvent(taskId: "tsk_001", state: "running", balanceAfter: 92)
        )
        taskContinuation.yield(
            AITaskEvent(taskId: "tsk_002", state: "done", balanceAfter: nil)
        )
        taskContinuation.finish()

        await fulfillment(of: [expectation], timeout: 1)
        consumer.cancel()
    }
}
