import XCTest
@testable import BabyCameraCamera

final class CameraConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let config = CameraConfiguration.default
        XCTAssertEqual(config.position, .back)
        XCTAssertEqual(config.flashMode, .auto)
        XCTAssertFalse(config.showsGrid)
        XCTAssertFalse(config.showsLevel)
        XCTAssertEqual(config.countdown, .off)
    }

    func testToggleCamera() {
        var config = CameraConfiguration.default
        config.toggleCamera()
        XCTAssertEqual(config.position, .front)
        config.toggleCamera()
        XCTAssertEqual(config.position, .back)
    }

    func testFlashModeCyclesThroughAllModes() {
        var mode: CameraFlashMode = .auto
        mode = mode.next()
        XCTAssertEqual(mode, .on)
        mode = mode.next()
        XCTAssertEqual(mode, .off)
        mode = mode.next()
        XCTAssertEqual(mode, .auto)
    }

    func testCountdownCyclesThroughAllModes() {
        var countdown: CameraCountdown = .off
        countdown = countdown.next()
        XCTAssertEqual(countdown, .three)
        countdown = countdown.next()
        XCTAssertEqual(countdown, .ten)
        countdown = countdown.next()
        XCTAssertEqual(countdown, .off)
    }

    func testConfigurationCodableRoundTrip() throws {
        let original = CameraConfiguration(
            position: .front,
            flashMode: .on,
            showsGrid: true,
            showsLevel: true,
            countdown: .ten
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CameraConfiguration.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testConfigurationMutatorsOnState() {
        let state = CameraState()
        state.updateConfiguration { config in
            config.showsGrid = true
            config.cycleFlashMode()
            config.cycleCountdown()
        }
        XCTAssertTrue(state.configuration.showsGrid)
        XCTAssertEqual(state.configuration.flashMode, .on)
        XCTAssertEqual(state.configuration.countdown, .three)
    }
}
