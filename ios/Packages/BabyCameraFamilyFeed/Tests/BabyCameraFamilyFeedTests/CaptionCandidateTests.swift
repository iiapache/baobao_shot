import BabyCameraNetwork
import XCTest

final class CaptionCandidateTests: XCTestCase {
    func testComposedTextJoinsHashtags() {
        let candidate = CaptionCandidate(
            text: "豆豆 · 第 10 天",
            hashtags: ["#宝宝成长", "#吉卜力"]
        )
        XCTAssertEqual(candidate.composedText, "豆豆 · 第 10 天 #宝宝成长 #吉卜力")
    }

    func testComposedTextWithoutHashtagsReturnsTextOnly() {
        let candidate = CaptionCandidate(text: "纯文案", hashtags: [])
        XCTAssertEqual(candidate.composedText, "纯文案")
    }
}
