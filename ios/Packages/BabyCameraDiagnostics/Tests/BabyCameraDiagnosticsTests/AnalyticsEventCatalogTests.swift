import XCTest
@testable import BabyCameraDiagnostics

final class AnalyticsEventCatalogTests: XCTestCase {
    func testEventCountIsAtLeast60() {
        XCTAssertGreaterThanOrEqual(AnalyticsEventCatalog.eventCount, 60)
    }

    func testAllEventNamesAreUnique() {
        let names = AnalyticsEventCatalog.allEventNames
        XCTAssertEqual(names.count, Set(names).count, "Duplicate event names in catalog")
    }

    func testAllEventNamesUseSnakeCase() {
        for name in AnalyticsEventCatalog.allEventNames {
            XCTAssertFalse(name.contains(" "), "Event name must not contain spaces: \(name)")
            XCTAssertEqual(name, name.lowercased(), "Event name must be lowercase: \(name)")
        }
    }

    func testEmitAllStubTracksCoversCatalog() {
        var tracked: [String] = []
        AnalyticsService.trackHandler = { event, _, _ in
            tracked.append(event)
        }

        AnalyticsFeatureTracks.emitAllStubTracksForVerification()

        let trackedSet = Set(tracked)
        let catalogSet = Set(AnalyticsEventCatalog.allEventNames)
        XCTAssertEqual(trackedSet, catalogSet)
    }
}
