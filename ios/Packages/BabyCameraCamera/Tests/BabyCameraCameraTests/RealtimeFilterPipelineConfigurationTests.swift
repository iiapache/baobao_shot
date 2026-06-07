import XCTest
@testable import BabyCameraCamera

final class RealtimeFilterPipelineConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let config = RealtimeFilterPipelineConfiguration.default
        XCTAssertEqual(config.activeFilter, .none)
        XCTAssertEqual(config.filterIntensity, 1.0, accuracy: 0.001)
        XCTAssertEqual(config.targetFrameRate, 30)
        XCTAssertFalse(config.cacheIntermediates)
        XCTAssertEqual(config.frameInterval, 1.0 / 30.0, accuracy: 0.0001)
    }

    func testFrameIntervalForCustomFrameRate() {
        var config = RealtimeFilterPipelineConfiguration.default
        config.targetFrameRate = 60
        XCTAssertEqual(config.frameInterval, 1.0 / 60.0, accuracy: 0.0001)
    }

    func testSelectFilterUpdatesIntensityToPresetDefault() {
        var config = RealtimeFilterPipelineConfiguration.default
        config.selectFilter(.sepia)
        XCTAssertEqual(config.activeFilter, .sepia)
        XCTAssertEqual(config.filterIntensity, 0.85, accuracy: 0.001)

        config.selectFilter(.mono)
        XCTAssertEqual(config.activeFilter, .mono)
        XCTAssertEqual(config.filterIntensity, 1.0, accuracy: 0.001)
    }

    func testSelectNoneResetsToOriginalPreset() {
        var config = RealtimeFilterPipelineConfiguration(activeFilter: .vivid, filterIntensity: 0.5)
        config.selectFilter(.none)
        XCTAssertEqual(config.activeFilter, .none)
        XCTAssertEqual(config.filterIntensity, 1.0, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let original = RealtimeFilterPipelineConfiguration(
            activeFilter: .chrome,
            filterIntensity: 0.75,
            targetFrameRate: 24,
            cacheIntermediates: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RealtimeFilterPipelineConfiguration.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
