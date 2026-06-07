import XCTest
@testable import BabyCameraMilestone

final class MilestoneCatalogTests: XCTestCase {
    override func tearDown() {
        MilestoneCatalog.resetForTesting()
        super.tearDown()
    }

    func testCatalogMeetsMinimumCount() {
        XCTAssertTrue(MilestoneCatalog.satisfiesMinimumCount)
        XCTAssertGreaterThanOrEqual(MilestoneCatalog.milestones.count, 10)
    }

    func testCatalogManifestParsesFromBundle() throws {
        let manifest = try MilestoneManifestLoader.loadCatalogFromBundle()
        XCTAssertEqual(manifest.schemaVersion, "1.0.0")
        XCTAssertGreaterThanOrEqual(manifest.milestones.count, 10)
    }

    func testCatalogLookupByID() {
        let hundredDays = MilestoneCatalog.milestone(for: "ms_hundred_days")
        XCTAssertNotNil(hundredDays)
        XCTAssertEqual(hundredDays?.name, "百天")
        XCTAssertEqual(hundredDays?.trigger.kind, .dayOffset)
        XCTAssertEqual(hundredDays?.trigger.day, 100)
        XCTAssertEqual(hundredDays?.templateId, "tpl_hundred_01")
    }

    func testCatalogIncludesPRDMilestones() {
        let expectedIDs = [
            "ms_sanzhao",
            "ms_full_moon",
            "ms_hundred_days",
            "ms_six_months",
            "ms_first_birthday",
            "ms_zhuazhou",
            "ms_birthday",
            "ms_children_day",
        ]
        for id in expectedIDs {
            XCTAssertNotNil(MilestoneCatalog.milestone(for: id), "缺少 PRD 里程碑 \(id)")
        }
    }

    func testCatalogSortedBySortField() {
        let sorts = MilestoneCatalog.milestones.map(\.sort)
        XCTAssertEqual(sorts, sorts.sorted())
    }
}
