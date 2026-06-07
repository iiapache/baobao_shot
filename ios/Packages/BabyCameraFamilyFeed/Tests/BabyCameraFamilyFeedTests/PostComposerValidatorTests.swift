import XCTest
@testable import BabyCameraFamilyFeed

final class PostComposerValidatorTests: XCTestCase {
    func testRejectsMoreThanNineImages() {
        let items = (0..<10).map {
            PostComposerMediaItem(kind: .image, width: 1, height: 1, objectKey: "key_\($0)")
        }

        let result = PostComposerValidator.validate(caption: "hello", items: items)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors, [.imageLimitExceeded(current: 10, max: 9)])
    }

    func testRejectsMoreThanOneVideo() {
        let items = [
            PostComposerMediaItem(kind: .video, width: 1, height: 1, objectKey: "v1"),
            PostComposerMediaItem(kind: .video, width: 1, height: 1, objectKey: "v2"),
        ]

        let result = PostComposerValidator.validate(caption: "hello", items: items)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors, [.videoLimitExceeded(current: 2, max: 1)])
    }

    func testRejectsEmptyContent() {
        let result = PostComposerValidator.validate(caption: "   ", items: [])
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(.emptyContent))
    }

    func testAllowsCaptionOnlyPublishDraft() {
        let result = PostComposerValidator.validate(caption: "只有文案", items: [])
        XCTAssertTrue(result.isValid)
    }

    func testValidateAddingImageBlocksTenthImage() {
        let items = (0..<9).map {
            PostComposerMediaItem(kind: .image, width: 1, height: 1)
        }
        let result = PostComposerValidator.validateAddingImage(to: items)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.first, .imageLimitExceeded(current: 10, max: 9))
    }

    func testValidateAddingVideoBlocksSecondVideo() {
        let items = [PostComposerMediaItem(kind: .video, width: 1, height: 1)]
        let result = PostComposerValidator.validateAddingVideo(to: items)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.first, .videoLimitExceeded(current: 2, max: 1))
    }

    func testRequiresUploadedObjectKeysForPublish() {
        let items = [PostComposerMediaItem(kind: .image, width: 1, height: 1)]
        let result = PostComposerValidator.validate(
            caption: "文案",
            items: items,
            requireUploadedObjectKeys: true
        )
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors, [.itemsNotUploaded(missingCount: 1)])
    }
}
