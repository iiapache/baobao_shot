import XCTest
@testable import BabyCameraCamera

@MainActor
final class CameraStateTests: XCTestCase {
    func testInitialViewState() {
        let state = CameraState()
        XCTAssertEqual(state.viewState.lifecycle, .idle)
        XCTAssertEqual(state.viewState.configuration, .default)
        XCTAssertFalse(state.viewState.permissionDenied)
        XCTAssertNil(state.viewState.countdownRemaining)
        XCTAssertFalse(state.viewState.hasReceivedFirstFrame)
    }

    func testLifecycleTransitions() {
        let state = CameraState()
        state.setLifecycle(.configuring)
        XCTAssertEqual(state.viewState.lifecycle, .configuring)
        state.setLifecycle(.running)
        XCTAssertEqual(state.viewState.lifecycle, .running)
        state.setLifecycle(.interrupted)
        XCTAssertEqual(state.viewState.lifecycle, .interrupted)
        state.setLifecycle(.failed(.permissionDenied))
        XCTAssertEqual(state.viewState.lifecycle, .failed(.permissionDenied))
    }

    func testCountdownState() {
        let state = CameraState()
        XCTAssertFalse(state.viewState.isCountingDown)

        state.setCountdownRemaining(3)
        XCTAssertTrue(state.viewState.isCountingDown)
        XCTAssertEqual(state.viewState.countdownRemaining, 3)

        state.setCountdownRemaining(0)
        XCTAssertFalse(state.viewState.isCountingDown)

        state.setCountdownRemaining(nil)
        XCTAssertFalse(state.viewState.isCountingDown)
    }

    func testFirstFrameTracking() {
        let state = CameraState()
        state.markFirstFrameReceived()
        XCTAssertTrue(state.viewState.hasReceivedFirstFrame)
        state.resetFirstFrame()
        XCTAssertFalse(state.viewState.hasReceivedFirstFrame)
    }
}
