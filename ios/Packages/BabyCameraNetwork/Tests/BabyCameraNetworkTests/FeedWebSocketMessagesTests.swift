import XCTest
@testable import BabyCameraNetwork

final class FeedWebSocketMessagesTests: XCTestCase {
    func testDecodeCommentAddedEvent() throws {
        let json = """
        {
          "op": "event",
          "kind": "comment_added",
          "familyId": "fam_001",
          "postId": "pst_001",
          "userId": "usr_002",
          "commentId": "cmt_001",
          "text": "好可爱",
          "createdAt": "2026-06-06T10:00:00Z"
        }
        """
        let message = try JSONDecoder().decode(FeedWebSocketServerMessage.self, from: Data(json.utf8))
        let event = FeedEngagementRemoteEvent(message: message)

        guard case let .commentAdded(familyId, postId, userId, commentId, text, createdAt) = event else {
            return XCTFail("expected commentAdded")
        }
        XCTAssertEqual(familyId, "fam_001")
        XCTAssertEqual(postId, "pst_001")
        XCTAssertEqual(userId, "usr_002")
        XCTAssertEqual(commentId, "cmt_001")
        XCTAssertEqual(text, "好可爱")
        XCTAssertEqual(createdAt, "2026-06-06T10:00:00Z")
    }

    func testEncodeSubscribeMessage() throws {
        let message = FeedWebSocketClientMessage.subscribe(familyIds: ["fam_001"])
        let data = try JSONEncoder().encode(message)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("subscribe"))
        XCTAssertTrue(json.contains("fam_001"))
    }
}
