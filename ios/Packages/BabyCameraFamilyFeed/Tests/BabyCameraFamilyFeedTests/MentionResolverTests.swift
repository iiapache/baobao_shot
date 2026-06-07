import XCTest
@testable import BabyCameraFamilyFeed

final class MentionResolverTests: XCTestCase {
    private let candidates = [
        FeedMentionCandidate(id: "usr_grandma", nickname: "外婆"),
        FeedMentionCandidate(id: "usr_dad", nickname: "爸爸"),
    ]

    func testExtractMentionTokens() {
        let tokens = MentionResolver.extractMentionTokens(from: "@外婆 今天很开心 @爸爸")
        XCTAssertEqual(tokens, ["外婆", "爸爸"])
    }

    func testResolveMentionUserIds() {
        let ids = MentionResolver.mentionUserIds(
            in: "看看 @外婆 的表情",
            candidates: candidates
        )
        XCTAssertEqual(ids, ["usr_grandma"])
    }

    func testInsertMention() {
        let text = MentionResolver.insertMention(
            FeedMentionCandidate(id: "usr_dad", nickname: "爸爸"),
            into: "真棒"
        )
        XCTAssertEqual(text, "真棒 @爸爸 ")
    }
}
