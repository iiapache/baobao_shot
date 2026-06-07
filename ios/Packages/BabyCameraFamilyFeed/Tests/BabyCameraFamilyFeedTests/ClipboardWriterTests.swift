import BabyCameraNetwork
import XCTest
@testable import BabyCameraFamilyFeed

final class ClipboardWriterTests: XCTestCase {
    func testWriteSmartCaptionIncludesHashtags() {
        let pasteboard = MockPasteboard()
        let writer = ClipboardWriter(pasteboard: pasteboard)
        let caption = CaptionCandidate(
            text: "豆豆 · 第 10 天",
            hashtags: ["#宝宝成长", "#吉卜力"]
        )

        let result = writer.writeSmartCaption(caption, destination: .system)

        XCTAssertEqual(result.composedText, "豆豆 · 第 10 天 #宝宝成长 #吉卜力")
        XCTAssertEqual(pasteboard.lastWrittenString, result.composedText)
        XCTAssertEqual(result.hintMessage, "智能文案已复制到剪贴板")
    }

    func testWriteSmartCaptionUsesDestinationSpecificHint() {
        let pasteboard = MockPasteboard()
        let writer = ClipboardWriter(pasteboard: pasteboard)
        let caption = CaptionCandidate(text: "分享文案", hashtags: ["#日常"])

        let xhs = writer.writeSmartCaption(caption, destination: .xiaohongshu)
        let douyin = writer.writeSmartCaption(caption, destination: .douyin)

        XCTAssertEqual(xhs.hintMessage, "智能文案已复制，分享至小红书后可直接粘贴")
        XCTAssertEqual(douyin.hintMessage, "智能文案已复制，分享至抖音后可直接粘贴")
    }

    func testWritePlainTextFallsBackWithoutHashtags() {
        let pasteboard = MockPasteboard()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let result = writer.writeSmartCaption(text: "默认文案", destination: .system)

        XCTAssertEqual(result.composedText, "默认文案")
        XCTAssertEqual(pasteboard.lastWrittenString, "默认文案")
    }
}

private final class MockPasteboard: PasteboardWriting, @unchecked Sendable {
    private(set) var lastWrittenString: String?

    func setString(_ value: String) {
        lastWrittenString = value
    }

    func string() -> String? {
        lastWrittenString
    }
}
