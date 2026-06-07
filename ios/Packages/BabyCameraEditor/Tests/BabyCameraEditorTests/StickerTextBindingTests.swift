import CoreImage
import XCTest
@testable import BabyCameraEditor

final class StickerTextBindingTests: XCTestCase {
    private let testExtent = CGRect(x: 0, y: 0, width: 128, height: 128)

    // MARK: - StickerCatalog

    func testStickerCatalogMeetsMinimumCount() {
        XCTAssertTrue(StickerCatalog.satisfiesMinimumCount)
        XCTAssertGreaterThanOrEqual(StickerCatalog.stickers.count, 60)
    }

    func testStickerCatalogHasAllCategories() {
        XCTAssertTrue(StickerCatalog.hasAllCategoriesRepresented)
        for category in StickerCategoryID.allCases {
            let items = StickerCatalog.stickers(in: category)
            XCTAssertFalse(items.isEmpty, "分类 \(category.displayName) 应有贴纸")
        }
    }

    func testStickerCatalogLookupByID() {
        let asset = StickerCatalog.sticker(for: "sticker_cute_star")
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset?.category, .cute)
        XCTAssertEqual(asset?.defaultScale, 0.3, accuracy: 0.0001)
    }

    func testStickerStepApplyProducesOutput() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent)
        let step = StickerStep(resourceID: "sticker_cute_heart", centerX: 0.5, centerY: 0.5)
        let output = step.apply(to: base)
        XCTAssertEqual(output.extent, base.extent)
    }

    func testStickerPanelBindingSelectCategory() {
        var binding = StickerPanelBinding(category: .cute)
        binding.selectCategory(.numbers)
        XCTAssertEqual(binding.category, .numbers)
        XCTAssertTrue(binding.availableStickers.allSatisfy { $0.category == .numbers })
    }

    func testStickerPanelBindingMakeStepUsesManifestID() {
        let binding = StickerPanelBinding(
            category: .milestones,
            stickerID: "sticker_ms_hundred_days"
        )
        let step = binding.makeStep()
        XCTAssertEqual(step.resourceID, "sticker_ms_hundred_days")
    }

    // MARK: - FontCatalog

    func testFontCatalogMeetsMinimumCount() {
        XCTAssertTrue(FontCatalog.satisfiesMinimumCount)
        XCTAssertGreaterThanOrEqual(FontCatalog.allEditorFonts.count, 6)
    }

    func testFontCatalogLicenseMetadataAlignedWithT011() {
        XCTAssertTrue(FontCatalog.allFontsAreCommerciallyLicensed)
        XCTAssertTrue(FontCatalog.licenseFilesAreDeclared)

        let expectedIDs: Set<String> = [
            "font_baobao_rounded",
            "font_baobao_serif",
            "font_baobao_handwriting",
            "font_baobao_cute",
            "font_baobao_bold",
            "font_baobao_elegant",
        ]
        let actualIDs = Set(FontCatalog.fonts.map(\.id))
        XCTAssertEqual(actualIDs, expectedIDs)
    }

    func testFontCatalogEditorTextFonts() {
        XCTAssertGreaterThanOrEqual(FontCatalog.editorTextFonts.count, 5)
        XCTAssertTrue(FontCatalog.editorTextFonts.allSatisfy(\.supportsEditorText))
    }

    func testTextPanelBindingMakeStepUsesPostScriptName() {
        var binding = TextPanelBinding(text: "宝宝百天", fontID: "font_baobao_bold")
        binding.selectFont("font_baobao_handwriting")
        let step = binding.makeStep()
        XCTAssertEqual(step.fontID, "font_baobao_handwriting")
        XCTAssertEqual(step.fontName, "BaobaoHandwriting-Regular")
    }

    func testTextStepApplyProducesOutput() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent, red: 0.2, green: 0.2, blue: 0.2)
        let step = TextStep(text: "Hi", fontName: "Helvetica", fontSize: 20, colorHex: "#FFFFFF")
        let output = step.apply(to: base)
        XCTAssertEqual(output.extent, base.extent)
    }

    // MARK: - Mosaic

    func testMosaicPanelBindingBlockSizeMapping() {
        var binding = MosaicPanelBinding()
        binding.setNormalizedBlockSize(0.5)
        let expected = MosaicPanelBinding.minBlockSize
            + 0.5 * (MosaicPanelBinding.maxBlockSize - MosaicPanelBinding.minBlockSize)
        XCTAssertEqual(binding.blockSize, expected, accuracy: 0.0001)
    }

    func testMosaicStepApplyProducesOutput() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent, red: 0.5, green: 0.5, blue: 0.5)
        let step = MosaicStep(region: NormalizedRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4))
        let output = step.apply(to: base)
        XCTAssertEqual(output.extent, base.extent)
    }

    // MARK: - Doodle

    func testDoodlePanelBindingStrokeLifecycle() {
        var binding = DoodlePanelBinding()
        XCTAssertFalse(binding.hasStroke)
        binding.appendPoint(DoodlePoint(x: 0.1, y: 0.1))
        binding.appendPoint(DoodlePoint(x: 0.2, y: 0.2))
        XCTAssertTrue(binding.hasStroke)
        let step = binding.makeStep()
        XCTAssertEqual(step.points.count, 2)
    }

    func testDoodleStepApplyWithCustomColor() {
        let base = TestCIImageFactory.makeSolidColor(extent: testExtent)
        let step = DoodleStep(
            strokeColorHex: "#00FF00",
            strokeWidth: 6,
            points: [
                DoodlePoint(x: 0.1, y: 0.1),
                DoodlePoint(x: 0.9, y: 0.9),
            ]
        )
        let output = step.apply(to: base)
        XCTAssertEqual(output.extent, base.extent)
    }

    // MARK: - Toolbar commit

    func testEditorToolbarCommitSticker() {
        let state = EditorState()
        var toolbar = EditorToolbarBinding(
            activePanel: .sticker,
            sticker: StickerPanelBinding(stickerID: "sticker_cute_star")
        )
        toolbar.commitActivePanel(to: state)
        XCTAssertEqual(state.stepCount, 1)
        XCTAssertEqual(state.steps.last?.kind, .sticker)
    }

    func testEditorToolbarCommitTextSkipsEmpty() {
        let state = EditorState()
        var toolbar = EditorToolbarBinding(activePanel: .text, text: TextPanelBinding(text: "   "))
        toolbar.commitActivePanel(to: state)
        XCTAssertEqual(state.stepCount, 0)
    }

    func testEditorToolbarCommitDoodleClearsPoints() {
        let state = EditorState()
        var doodle = DoodlePanelBinding()
        doodle.appendPoint(DoodlePoint(x: 0.1, y: 0.1))
        doodle.appendPoint(DoodlePoint(x: 0.2, y: 0.2))
        var toolbar = EditorToolbarBinding(activePanel: .doodle, doodle: doodle)
        toolbar.commitActivePanel(to: state)
        XCTAssertEqual(state.stepCount, 1)
        XCTAssertTrue(toolbar.doodle.points.isEmpty)
    }
}
