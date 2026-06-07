import XCTest
@testable import BabyCameraEditor

final class EditStepCodableTests: XCTestCase {
    func testAllStepKindsRoundTripJSON() throws {
        let steps: [AnyEditStep] = [
            .filter(FilterStep(filterID: .sepia, intensity: 0.8)),
            .adjust(AdjustStep(parameters: AdjustParameters(brightness: 0.05, contrast: 1.1))),
            .crop(CropStep(rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5))),
            .rotate(RotateStep(degrees: 90)),
            .sticker(StickerStep(resourceID: "sticker_cute_star", centerX: 0.5, centerY: 0.5)),
            .text(TextStep(text: "宝宝百天", fontName: "BaobaoRounded-Regular", fontID: "font_baobao_rounded")),
            .mosaic(MosaicStep(region: NormalizedRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3))),
            .doodle(DoodleStep(points: [DoodlePoint(x: 0.1, y: 0.1), DoodlePoint(x: 0.2, y: 0.2)])),
            .template(TemplateStep(
                templateID: "growth_card_01",
                placeholders: [TemplatePlaceholder(key: "babyName", value: "小宝")],
                nestedSteps: [.filter(FilterStep(filterID: .fade))]
            )),
        ]

        let data = try JSONEncoder().encode(steps)
        let decoded = try JSONDecoder().decode([AnyEditStep].self, from: data)

        XCTAssertEqual(decoded.count, steps.count)
        for (original, restored) in zip(steps, decoded) {
            XCTAssertEqual(original, restored)
        }
    }

    func testEditorStateEncodedStepsRoundTrip() throws {
        let state = EditorState()
        state.append(FilterStep(filterID: .vivid))
        state.append(RotateStep(degrees: 180))

        let data = try state.encodedSteps()
        let restored = try EditorState.decodeSteps(from: data)
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].kind, .filter)
        XCTAssertEqual(restored[1].kind, .rotate)
    }
}
