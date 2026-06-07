import BabyCameraWatermark
import CoreGraphics
import XCTest
@testable import BabyCameraFamilyFeed

final class ShareGateTests: XCTestCase {
    private var tempRoot: URL!
    private var gate: ShareGate!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareGate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        gate = ShareGate(fileManager: .default)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testValidateRejectsMissingSource() {
        let request = SharePreparationRequest(
            sourceURL: tempRoot.appendingPathComponent("missing.jpg"),
            mediaKind: .image,
            isSubscribed: false,
            requiresDeepSynthesisBadge: false
        )

        XCTAssertThrowsError(try gate.validate(request)) { error in
            XCTAssertEqual(error as? ShareGateError, .sourceMissing)
        }
    }

    func testValidateRejectsUnsupportedImageExtension() throws {
        let sourceURL = tempRoot.appendingPathComponent("photo.png")
        try Data([0x01]).write(to: sourceURL)

        let request = SharePreparationRequest(
            sourceURL: sourceURL,
            mediaKind: .image,
            isSubscribed: false,
            requiresDeepSynthesisBadge: false
        )

        XCTAssertThrowsError(try gate.validate(request)) { error in
            XCTAssertEqual(error as? ShareGateError, .unsupportedImageExtension("png"))
        }
    }

    func testValidateAcceptsExistingVideoSource() throws {
        let sourceURL = tempRoot.appendingPathComponent("clip.mp4")
        try Data("video".utf8).write(to: sourceURL)

        let request = SharePreparationRequest(
            sourceURL: sourceURL,
            mediaKind: .video,
            isSubscribed: true,
            requiresDeepSynthesisBadge: true
        )

        XCTAssertNoThrow(try gate.validate(request))
    }

    func testWatermarkOptionsForcesDeepSynthesisBadgeOnAIContent() {
        let request = SharePreparationRequest(
            sourceURL: tempRoot.appendingPathComponent("ai.heic"),
            mediaKind: .image,
            isSubscribed: true,
            requiresDeepSynthesisBadge: true
        )

        let options = gate.watermarkOptions(for: request)
        XCTAssertTrue(options.includeDeepSynthesisBadge)
    }

    func testWatermarkOptionsSkipsDeepSynthesisBadgeForCameraCapture() {
        let request = SharePreparationRequest(
            sourceURL: tempRoot.appendingPathComponent("camera.jpg"),
            mediaKind: .image,
            isSubscribed: false,
            requiresDeepSynthesisBadge: false
        )

        let options = gate.watermarkOptions(for: request)
        XCTAssertFalse(options.includeDeepSynthesisBadge)
    }

    func testBadgeLayoutCompliantForStandardCanvas() {
        let canvas = CGSize(width: 1080, height: 1920)
        XCTAssertTrue(gate.isBadgeLayoutCompliant(canvasSize: canvas))
    }

    func testBadgeLayoutRejectsZeroCanvas() {
        XCTAssertFalse(gate.isBadgeLayoutCompliant(canvasSize: .zero))
    }
}
