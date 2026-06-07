import XCTest
@testable import BabyCameraCamera

@MainActor
final class CameraSessionTests: XCTestCase {
    func testMockSessionLifecycle() throws {
        let session = MockCameraSession()
        XCTAssertEqual(session.lifecycle, .idle)

        try session.configure(with: .default)
        XCTAssertEqual(session.configureCallCount, 1)
        XCTAssertEqual(session.lifecycle, .idle)

        try session.startRunning()
        XCTAssertEqual(session.startCallCount, 1)
        XCTAssertEqual(session.lifecycle, .running)

        session.stopRunning()
        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertEqual(session.lifecycle, .idle)
    }

    func testMockSessionSwitchCameraUpdatesConfiguration() throws {
        let session = MockCameraSession()
        try session.configure(with: .default)
        XCTAssertEqual(session.configuration.position, .back)

        try session.switchCamera()
        XCTAssertEqual(session.switchCallCount, 1)
        XCTAssertEqual(session.configuration.position, .front)
    }

    func testMockSessionFlashMode() throws {
        let session = MockCameraSession()
        try session.setFlashMode(.on)
        XCTAssertEqual(session.flashCallCount, 1)
        XCTAssertEqual(session.configuration.flashMode, .on)
    }

    func testMockSessionInterruption() throws {
        let session = MockCameraSession()
        try session.startRunning()
        session.setSessionInterrupted(true)
        XCTAssertEqual(session.lifecycle, .interrupted)
        session.setSessionInterrupted(false)
        XCTAssertEqual(session.lifecycle, .running)
    }

    func testConfigureFailureSetsFailedLifecycle() {
        let session = MockCameraSession()
        session.shouldFailConfigure = true
        XCTAssertThrowsError(try session.configure(with: .default)) { error in
            XCTAssertEqual(error as? CameraSessionError, .configurationFailed)
        }
        XCTAssertEqual(session.lifecycle, .failed(.configurationFailed))
    }
}
