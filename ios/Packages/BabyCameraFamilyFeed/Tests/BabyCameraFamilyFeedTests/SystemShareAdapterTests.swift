import BabyCameraImageKit
import BabyCameraNetwork
import BabyCameraWatermark
import UIKit
import XCTest
@testable import BabyCameraFamilyFeed

@MainActor
final class SystemShareAdapterTests: XCTestCase {
    private let codec = ImageCodec()
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SystemShare-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testSharePreparesAssetWritesClipboardAndPresentsActivitySheet() async throws {
        let sourceURL = try writeSolidImage(named: "share.jpg", format: .jpeg)
        let pasteboard = MockPasteboard()
        let presenter = MockShareActivityPresenter()
        let adapter = SystemShareAdapter(
            preparer: SharePreparer(renderer: WatermarkRenderer(policy: NeverShowBrandWatermarkPolicy())),
            clipboardWriter: ClipboardWriter(pasteboard: pasteboard),
            activityPresenter: presenter
        )
        let caption = CaptionCandidate(
            text: "豆豆 · 第 30 天",
            hashtags: ["#宝宝成长"]
        )
        let request = SystemShareRequest(
            preparationRequest: SharePreparationRequest(
                sourceURL: sourceURL,
                mediaKind: .image,
                isSubscribed: true,
                requiresDeepSynthesisBadge: true
            ),
            caption: caption,
            fallbackCaption: "兜底文案",
            destination: .xiaohongshu
        )
        let viewController = UIViewController()

        let outcome = try await adapter.share(request, from: viewController)

        XCTAssertTrue(outcome.preparedAsset.appliedDeepSynthesisBadge)
        XCTAssertEqual(outcome.clipboardResult.composedText, "豆豆 · 第 30 天 #宝宝成长")
        XCTAssertEqual(
            outcome.clipboardResult.hintMessage,
            "智能文案已复制，分享至小红书后可直接粘贴"
        )
        XCTAssertEqual(outcome.destination, .xiaohongshu)
        XCTAssertEqual(outcome.presentation.fileURLs, [outcome.preparedAsset.mediaURL])
        XCTAssertEqual(presenter.presentCallCount, 1)
        XCTAssertEqual(presenter.lastPresentation, outcome.presentation)
        XCTAssertEqual(pasteboard.lastWrittenString, outcome.clipboardResult.composedText)
        XCTAssertNotEqual(outcome.preparedAsset.mediaURL, sourceURL)
    }

    func testShareUsesFallbackCaptionWhenCandidateMissing() async throws {
        let sourceURL = try writeSolidImage(named: "fallback.jpg", format: .jpeg)
        let pasteboard = MockPasteboard()
        let adapter = SystemShareAdapter(
            preparer: SharePreparer(renderer: WatermarkRenderer(policy: NeverShowBrandWatermarkPolicy())),
            clipboardWriter: ClipboardWriter(pasteboard: pasteboard),
            activityPresenter: MockShareActivityPresenter()
        )
        let request = SystemShareRequest(
            preparationRequest: SharePreparationRequest(
                sourceURL: sourceURL,
                mediaKind: .image,
                isSubscribed: false,
                requiresDeepSynthesisBadge: false
            ),
            caption: nil,
            fallbackCaption: "豆豆 · 第 1 天 · 吉卜力",
            destination: .douyin
        )

        let outcome = try await adapter.share(request, from: UIViewController())

        XCTAssertEqual(outcome.clipboardResult.composedText, "豆豆 · 第 1 天 · 吉卜力")
        XCTAssertEqual(
            outcome.clipboardResult.hintMessage,
            "智能文案已复制，分享至抖音后可直接粘贴"
        )
        XCTAssertEqual(pasteboard.lastWrittenString, "豆豆 · 第 1 天 · 吉卜力")
    }

    func testShareRoutesSystemAndSocialDestinationsThroughActivityPresenter() async throws {
        let sourceURL = try writeSolidImage(named: "route.jpg", format: .jpeg)
        let presenter = MockShareActivityPresenter()
        let adapter = SystemShareAdapter(
            preparer: SharePreparer(renderer: WatermarkRenderer(policy: NeverShowBrandWatermarkPolicy())),
            clipboardWriter: ClipboardWriter(pasteboard: MockPasteboard()),
            activityPresenter: presenter
        )
        let preparation = SharePreparationRequest(
            sourceURL: sourceURL,
            mediaKind: .image,
            isSubscribed: false,
            requiresDeepSynthesisBadge: false
        )

        for destination in ShareDestination.allCases {
            presenter.presentCallCount = 0
            let outcome = try await adapter.share(
                SystemShareRequest(
                    preparationRequest: preparation,
                    fallbackCaption: "文案",
                    destination: destination
                ),
                from: UIViewController()
            )

            XCTAssertTrue(destination.usesSystemShareSheet)
            XCTAssertEqual(presenter.presentCallCount, 1)
            XCTAssertEqual(outcome.destination, destination)
        }
    }

    func testSharePropagatesPreparerFailure() async throws {
        let adapter = SystemShareAdapter(
            preparer: SharePreparer(),
            clipboardWriter: ClipboardWriter(pasteboard: MockPasteboard()),
            activityPresenter: MockShareActivityPresenter()
        )
        let request = SystemShareRequest(
            preparationRequest: SharePreparationRequest(
                sourceURL: tempRoot.appendingPathComponent("missing.jpg"),
                mediaKind: .image,
                isSubscribed: false,
                requiresDeepSynthesisBadge: false
            ),
            fallbackCaption: "文案",
            destination: .system
        )

        do {
            _ = try await adapter.share(request, from: UIViewController())
            XCTFail("Expected preparation failure")
        } catch let error as SystemShareError {
            XCTAssertEqual(error, .preparationFailed(.sourceMissing))
        }
    }

    private func writeSolidImage(named fileName: String, format: ImageFormat) throws -> URL {
        let image = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .blue)
        let encoded = try codec.encode(image: image, format: format)
        let url = tempRoot.appendingPathComponent(fileName)
        try encoded.data.write(to: url)
        return url
    }
}

@MainActor
private final class MockShareActivityPresenter: ShareActivityPresenting {
    private(set) var presentCallCount = 0
    private(set) var lastPresentation: ShareActivityPresentation?

    func present(
        _ presentation: ShareActivityPresentation,
        from viewController: UIViewController
    ) {
        presentCallCount += 1
        lastPresentation = presentation
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

private enum TestImageFactory {
    static func makeSolidColorImage(width: Int, height: Int, color: CGColor) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}

private extension CGColor {
    static var blue: CGColor {
        CGColor(red: 0.1, green: 0.2, blue: 0.9, alpha: 1)
    }
}
