import CoreImage
import XCTest
@testable import BabyCameraEditor

final class EditorStateTests: XCTestCase {
    func testAppendIncreasesStepCount() {
        let state = EditorState()
        XCTAssertEqual(state.stepCount, 0)
        XCTAssertFalse(state.canUndo)

        state.append(FilterStep(filterID: .sepia))
        XCTAssertEqual(state.stepCount, 1)
        XCTAssertTrue(state.canUndo)
        XCTAssertFalse(state.canRedo)
    }

    func testUndoRedoRestoresSteps() {
        let state = EditorState()
        state.append(FilterStep(filterID: .sepia))
        state.append(AdjustStep(parameters: AdjustParameters(brightness: 0.1)))

        XCTAssertEqual(state.stepCount, 2)

        state.undo()
        XCTAssertEqual(state.stepCount, 1)
        XCTAssertTrue(state.canRedo)

        state.redo()
        XCTAssertEqual(state.stepCount, 2)
        XCTAssertFalse(state.canRedo)
    }

    func testNewEditClearsRedoStack() {
        let state = EditorState()
        state.append(FilterStep(filterID: .mono))
        state.append(RotateStep(degrees: 90))
        state.undo()
        XCTAssertTrue(state.canRedo)

        state.append(CropStep(rect: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)))
        XCTAssertFalse(state.canRedo)
        XCTAssertEqual(state.stepCount, 2)
        XCTAssertEqual(state.steps.last?.kind, .crop)
    }

    func testRemoveLastStep() {
        let state = EditorState()
        state.append(FilterStep(filterID: .fade))
        state.append(FilterStep(filterID: .vivid))
        state.removeLastStep()

        XCTAssertEqual(state.stepCount, 1)
        XCTAssertEqual(state.steps.first?.kind, .filter)
    }

    func testReplaceStepsClearsHistory() {
        let state = EditorState()
        state.append(FilterStep(filterID: .sepia))
        state.replaceSteps([.adjust(AdjustStep(parameters: AdjustParameters(contrast: 1.2)))])
        XCTAssertEqual(state.stepCount, 1)
        XCTAssertFalse(state.canUndo)
    }

    func testRenderAppliesAllSteps() {
        let base = TestCIImageFactory.makeSolidColor(extent: CGRect(x: 0, y: 0, width: 100, height: 100))
        let state = EditorState()
        state.append(FilterStep(filterID: .mono))

        let rendered = state.render(baseImage: base)
        XCTAssertFalse(rendered.extent.isEmpty)
    }
}
