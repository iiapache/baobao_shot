import CoreImage
import XCTest
@testable import BabyCameraEditor

final class FilterStepTests: XCTestCase {
    private let testExtent = CGRect(x: 0, y: 0, width: 128, height: 128)

    func testCatalogMeetsMinimumFilterCount() {
        XCTAssertTrue(FilterCatalog.satisfiesMinimumCount)
        XCTAssertGreaterThanOrEqual(FilterCatalog.editablePresets.count, 12)
    }

    func testAllCategoriesRepresented() {
        XCTAssertTrue(FilterCatalog.hasAllCategoriesRepresented)
        for category in FilterCategory.allCases {
            let presets = FilterCatalog.presets(in: category)
            XCTAssertFalse(presets.isEmpty, "分类 \(category.displayName) 应有至少一款滤镜")
        }
    }

    func testFilterPresetCategoryMapping() {
        XCTAssertEqual(FilterCatalog.category(for: .vivid), .daily)
        XCTAssertEqual(FilterCatalog.category(for: .mono), .portrait)
        XCTAssertEqual(FilterCatalog.category(for: .sepia), .film)
        XCTAssertEqual(FilterCatalog.category(for: .comic), .cartoon)
    }

    func testNoneFilterIsPassthrough() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent)
        let step = FilterStep(filterID: .none, intensity: 0.5)
        let output = step.apply(to: base)
        XCTAssertEqual(output.extent, base.extent)
    }

    func testEachEditableFilterProducesOutput() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent, red: 0.8, green: 0.2, blue: 0.4)

        for preset in FilterCatalog.editablePresets {
            let step = FilterStep(filterID: preset.id, intensity: preset.defaultIntensity)
            let output = step.apply(to: base)
            XCTAssertFalse(output.extent.isEmpty, "滤镜 \(preset.id) 应产生有效输出")
        }
    }

    func testIntensityZeroReturnsOriginalExtent() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent, red: 0.2, green: 0.6, blue: 0.9)
        let zero = FilterStep(filterID: .vivid, intensity: 0.0).apply(to: base)
        XCTAssertEqual(zero.extent, base.extent)
    }

    func testFilterStepCodableRoundTrip() throws {
        let step = FilterStep(filterID: .posterize, intensity: 0.75)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(FilterStep.self, from: data)
        XCTAssertEqual(decoded, step)
    }

    func testFilterPanelBindingSelectCategoryUpdatesFilter() {
        var binding = FilterPanelBinding(category: .daily, filterID: .vivid)
        binding.selectCategory(.cartoon)
        XCTAssertEqual(binding.category, .cartoon)
        XCTAssertEqual(FilterCatalog.category(for: binding.filterID), .cartoon)
    }
}
