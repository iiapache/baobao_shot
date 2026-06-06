import CoreImage
import XCTest
@testable import BabyCameraEditor

/// T2.11 验收：连续 100 步操作 + 全量撤销/重做，快照栈无异常增长。
final class EditorStressTests: XCTestCase {
    private let operationCount = 100

    func testHundredStepUndoRedoCycle() {
        let state = EditorState()
        var expectedKinds: [EditStepKind] = []

        for index in 0..<operationCount {
            autoreleasepool {
                let step = Self.makeStep(for: index)
                state.append(step)
                expectedKinds.append(step.kind)
            }
        }

        XCTAssertEqual(state.stepCount, operationCount)
        XCTAssertEqual(state.undoSnapshotCount, operationCount)

        for _ in 0..<operationCount {
            autoreleasepool {
                state.undo()
            }
        }

        XCTAssertEqual(state.stepCount, 0)
        XCTAssertFalse(state.canUndo)
        XCTAssertTrue(state.canRedo)
        XCTAssertEqual(state.redoSnapshotCount, operationCount)

        for _ in 0..<operationCount {
            autoreleasepool {
                state.redo()
            }
        }

        XCTAssertEqual(state.stepCount, operationCount)
        XCTAssertEqual(state.steps.map(\.kind), expectedKinds)
        XCTAssertFalse(state.canRedo)
    }

    func testHundredStepRenderWithoutLeakSymptoms() {
        let base = TestCIImageFactory.makeSolidColor(extent: CGRect(x: 0, y: 0, width: 64, height: 64))
        let state = EditorState()

        for index in 0..<operationCount {
            autoreleasepool {
                state.append(Self.makeStep(for: index))
                _ = state.render(baseImage: base)
            }
        }

        XCTAssertEqual(state.stepCount, operationCount)

        // 分支编辑后 redo 应被清空，栈深度可控
        for _ in 0..<50 {
            state.undo()
        }
        state.append(FilterStep(filterID: .none))
        XCTAssertFalse(state.canRedo)
        XCTAssertEqual(state.redoSnapshotCount, 0)
    }

    func testMaxUndoLevelsTrimsStack() {
        let maxLevels = 20
        let state = EditorState(maxUndoLevels: maxLevels)

        for index in 0..<operationCount {
            state.append(FilterStep(filterID: Self.filterID(for: index)))
        }

        XCTAssertEqual(state.undoSnapshotCount, maxLevels)
        XCTAssertEqual(state.stepCount, operationCount)
    }

    private static func makeStep(for index: Int) -> AnyEditStep {
        switch index % 9 {
        case 0:
            return .filter(FilterStep(filterID: filterID(for: index), intensity: Double(index % 10) / 10))
        case 1:
            return .adjust(AdjustStep(parameters: AdjustParameters(brightness: Double(index) * 0.001)))
        case 2:
            return .crop(CropStep(rect: NormalizedRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)))
        case 3:
            return .rotate(RotateStep(degrees: Double(index % 360)))
        case 4:
            return .sticker(StickerStep(resourceID: "s\(index)", centerX: 0.5, centerY: 0.5))
        case 5:
            return .text(TextStep(text: "t\(index)"))
        case 6:
            return .mosaic(MosaicStep(region: NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)))
        case 7:
            return .doodle(DoodleStep(points: [DoodlePoint(x: 0.1, y: 0.1), DoodlePoint(x: 0.2, y: 0.2)]))
        default:
            return .template(TemplateStep(
                templateID: "tpl_\(index)",
                nestedSteps: [.filter(FilterStep(filterID: .fade))]
            ))
        }
    }

    private static func filterID(for index: Int) -> FilterIdentifier {
        FilterIdentifier.allCases[index % FilterIdentifier.allCases.count]
    }
}
