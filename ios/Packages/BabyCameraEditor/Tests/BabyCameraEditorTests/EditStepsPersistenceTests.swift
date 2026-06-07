import XCTest
@testable import BabyCameraEditor

final class EditStepsPersistenceTests: XCTestCase {
    private var tempDirectory: URL!
    private var persistence: EditStepsPersistence!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        persistence = EditStepsPersistence(metaDirectory: tempDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testSaveAndLoadRoundTrip() throws {
        let photoId = UUID().uuidString
        var state = EditorState()
        state.append(FilterStep(filterID: .vivid, intensity: 0.7))
        state.append(CropStep(rect: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)))

        let savedURL = try persistence.save(editorState: state, photoId: photoId)
        XCTAssertTrue(savedURL.path.contains("edit_steps"))
        XCTAssertTrue(savedURL.lastPathComponent == "\(photoId).json")
        XCTAssertTrue(persistence.exists(photoId: photoId))

        let restored = try persistence.loadEditorState(photoId: photoId)
        XCTAssertEqual(restored.stepCount, 2)
        XCTAssertEqual(restored.steps[0].kind, .filter)
        XCTAssertEqual(restored.steps[1].kind, .crop)
    }

    func testRestoreViaEditorStateHelper() throws {
        let photoId = "derived-001"
        let state = EditorState()
        state.append(RotateStep(degrees: 90))
        _ = try state.persist(photoId: photoId, using: persistence)

        let restored = try EditorState.restore(photoId: photoId, using: persistence)
        XCTAssertEqual(restored.stepCount, 1)
        XCTAssertEqual(restored.steps[0].kind, .rotate)
    }

    func testLoadMissingStepsThrows() {
        XCTAssertThrowsError(try persistence.load(photoId: "missing-id")) { error in
            guard case EditorPersistenceError.stepsNotFound(let id) = error else {
                return XCTFail("Expected stepsNotFound, got \(error)")
            }
            XCTAssertEqual(id, "missing-id")
        }
    }

    func testSaveEmptyPhotoIdThrows() {
        XCTAssertThrowsError(try persistence.save(steps: [], photoId: "   ")) { error in
            XCTAssertEqual(error as? EditorPersistenceError, .photoIdEmpty)
        }
    }

    func testDeleteRemovesFile() throws {
        let photoId = "to-delete"
        try persistence.save(steps: [.filter(FilterStep(filterID: .fade))], photoId: photoId)
        XCTAssertTrue(persistence.exists(photoId: photoId))

        try persistence.delete(photoId: photoId)
        XCTAssertFalse(persistence.exists(photoId: photoId))
    }

    func testEncodedStepsPersistenceMatchesEditorStateAPI() throws {
        let photoId = "round-trip"
        let state = EditorState()
        state.append(TextStep(text: "百天快乐", fontName: "BaobaoRounded-Regular", fontID: "font_baobao_rounded"))

        let data = try state.encodedSteps()
        let url = persistence.fileURL(for: photoId)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)

        let loadedSteps = try persistence.load(photoId: photoId)
        let decodedDirectly = try EditorState.decodeSteps(from: data)
        XCTAssertEqual(loadedSteps, decodedDirectly)
    }
}
