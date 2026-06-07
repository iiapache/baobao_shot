import XCTest
@testable import BabyCameraCamera

final class RealtimeFilterIdentifierTests: XCTestCase {
    func testAllCasesContainExpectedIdentifiers() {
        let ids = Set(RealtimeFilterIdentifier.allCases.map(\.rawValue))
        let expected: Set<String> = [
            "none", "sepia", "mono", "vivid", "fade", "chrome", "instant", "noir",
        ]
        XCTAssertEqual(ids, expected)
    }

    func testOnlyNoneIsOriginal() {
        for identifier in RealtimeFilterIdentifier.allCases {
            if identifier == .none {
                XCTAssertTrue(identifier.isOriginal)
            } else {
                XCTAssertFalse(identifier.isOriginal)
            }
        }
    }

    func testCodableRoundTrip() throws {
        for identifier in RealtimeFilterIdentifier.allCases {
            let data = try JSONEncoder().encode(identifier)
            let decoded = try JSONDecoder().decode(RealtimeFilterIdentifier.self, from: data)
            XCTAssertEqual(decoded, identifier)
        }
    }

    func testPreviewFilterCountMeetsMinimum() {
        XCTAssertGreaterThanOrEqual(
            RealtimeFilterCatalog.previewPresets.count,
            RealtimeFilterCatalog.minimumPreviewFilterCount
        )
        XCTAssertTrue(RealtimeFilterCatalog.satisfiesMinimumCount)
    }

    func testEachPreviewPresetHasCIFilterName() {
        for preset in RealtimeFilterCatalog.previewPresets {
            XCTAssertFalse(preset.displayName.isEmpty)
            XCTAssertNotNil(preset.ciFilterName, "预设 \(preset.id) 缺少 CIFilter 名称")
        }
    }

    func testNonePresetHasNoCIFilterName() {
        let preset = RealtimeFilterCatalog.preset(for: .none)
        XCTAssertNil(preset.ciFilterName)
        XCTAssertEqual(preset.displayName, "原图")
    }

    func testPresetLookupReturnsMatchingPreset() {
        for identifier in RealtimeFilterIdentifier.allCases {
            let preset = RealtimeFilterCatalog.preset(for: identifier)
            XCTAssertEqual(preset.id, identifier)
        }
    }
}
