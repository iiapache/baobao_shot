import BabyCameraNetwork
import Database
import XCTest
@testable import BabyCameraFamilyFeed

final class FeedPostCacheMapperTests: XCTestCase {
    func testRoundTripPreservesMetadata() throws {
        let post = FeedPost(
            postId: "pst_001",
            familyId: "fam_001",
            ownerUserId: "usr_001",
            babyIds: ["bb_001", "bb_002"],
            caption: "测试文案",
            visibility: "family",
            status: "published",
            createdAt: "2026-06-06T10:00:00Z",
            mediaItems: [
                FeedMediaItem(
                    itemId: "pi_001",
                    kind: "image",
                    objectKey: "family/fam_001/post/1.heic",
                    width: 1024,
                    height: 768,
                    deepSynth: true
                ),
            ]
        )

        let record = try FeedPostCacheMapper.toCacheRecord(post, syncedAt: 1_700_000_000)
        let restored = try FeedPostCacheMapper.fromCacheRecord(record)

        XCTAssertEqual(restored, post)
    }
}
