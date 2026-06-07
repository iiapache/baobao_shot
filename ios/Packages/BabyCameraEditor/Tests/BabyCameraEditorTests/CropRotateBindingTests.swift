import XCTest
@testable import BabyCameraEditor

final class CropRotateBindingTests: XCTestCase {
    func testCropAspectRatioCenteredRect() {
        let square = NormalizedRect.centered(aspectRatio: .square)
        XCTAssertEqual(square.width, square.height, accuracy: 0.0001)
        XCTAssertEqual(square.x, 0, accuracy: 0.0001)
        XCTAssertEqual(square.y, 0, accuracy: 0.0001)
    }

    func testCropPanelBindingSelectAspectRatio() {
        var binding = CropPanelBinding()
        binding.selectAspectRatio(.landscape169)
        XCTAssertEqual(binding.aspectRatio, .landscape169)
        XCTAssertGreaterThan(binding.rect.width, binding.rect.height)
    }

    func testRotatePanelBindingRotate90() {
        var binding = RotatePanelBinding(degrees: 0)
        binding.rotate90Clockwise()
        XCTAssertEqual(binding.degrees, 90)
    }

    func testRotatePanelBindingMirrorToggle() {
        var binding = RotatePanelBinding()
        binding.toggleMirrorHorizontal()
        XCTAssertTrue(binding.mirrorHorizontal)
        binding.toggleMirrorVertical()
        XCTAssertTrue(binding.mirrorVertical)
    }

    func testEditorToolbarCommitAdjustSkipsNeutral() {
        let state = EditorState()
        var toolbar = EditorToolbarBinding(activePanel: .adjust)
        toolbar.commitActivePanel(to: state)
        XCTAssertEqual(state.stepCount, 0)

        toolbar.adjust.parameters.brightness = 0.2
        toolbar.commitActivePanel(to: state)
        XCTAssertEqual(state.stepCount, 1)
        XCTAssertEqual(state.steps.last?.kind, .adjust)
    }
}
