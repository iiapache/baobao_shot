import XCTest
@testable import BabyCameraFamilyFeed

final class PostMediaLimitsTests: XCTestCase {
    func testImageAndVideoCounts() {
        let items = [
            makeImage(id: "1"),
            makeImage(id: "2"),
            makeVideo(id: "3"),
        ]

        XCTAssertEqual(PostMediaLimits.imageCount(in: items), 2)
        XCTAssertEqual(PostMediaLimits.videoCount(in: items), 1)
    }

    func testCanAddImageUntilNine() {
        var items: [PostComposerMediaItem] = []
        for index in 0..<9 {
            XCTAssertTrue(PostMediaLimits.canAddImage(currentItems: items))
            items.append(makeImage(id: "img_\(index)"))
        }
        XCTAssertFalse(PostMediaLimits.canAddImage(currentItems: items))
        XCTAssertEqual(PostMediaLimits.remainingImageSlots(in: items), 0)
    }

    func testCanAddOnlyOneVideo() {
        XCTAssertTrue(PostMediaLimits.canAddVideo(currentItems: []))
        let items = [makeVideo(id: "vid_1")]
        XCTAssertFalse(PostMediaLimits.canAddVideo(currentItems: items))
        XCTAssertEqual(PostMediaLimits.remainingVideoSlots(in: items), 0)
    }

    private func makeImage(id: String) -> PostComposerMediaItem {
        PostComposerMediaItem(kind: .image, width: 100, height: 100)
    }

    private func makeVideo(id: String) -> PostComposerMediaItem {
        PostComposerMediaItem(kind: .video, width: 1920, height: 1080)
    }
}
