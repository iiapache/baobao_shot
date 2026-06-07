import BabyCameraImageKit
import CoreGraphics
import Foundation
import XCTest
@testable import BabyCameraFamilyFeed

final class WechatShareAdapterTests: XCTestCase {
    private let codec = ImageCodec()
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("WechatShare-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testUniversalLinkValidatorAcceptsValidLink() {
        XCTAssertTrue(WechatUniversalLinkValidator.validate("https://app.babycamera.cn/wechat/"))
    }

    func testUniversalLinkValidatorRejectsInvalidLinks() {
        XCTAssertFalse(WechatUniversalLinkValidator.validate("http://app.babycamera.cn/wechat/"))
        XCTAssertFalse(WechatUniversalLinkValidator.validate("https://app.babycamera.cn/wechat"))
        XCTAssertFalse(WechatUniversalLinkValidator.validate("https://app.babycamera.cn/wechat/#bad"))
        XCTAssertFalse(WechatUniversalLinkValidator.validate("not-a-url"))
    }

    func testShareToTimelineUsesCaptionAsTitle() async throws {
        let imageURL = try writeSolidImage(named: "share.jpg")
        let asset = SharePreparedAsset(
            mediaURL: imageURL,
            thumbnailURL: nil,
            mediaKind: .image,
            appliedDeepSynthesisBadge: true,
            appliedBrandWatermark: false
        )
        let bridge = SpyWechatOpenSDKBridge()
        let adapter = WechatShareAdapter(bridge: bridge)

        try await adapter.share(
            WechatShareRequest(
                asset: asset,
                caption: "小满 · 第 120 天 · 吉卜力风 #宝宝成长",
                scene: .timeline
            )
        )

        let payload = try XCTUnwrap(bridge.lastPayload)
        XCTAssertEqual(payload.scene, .timeline)
        XCTAssertEqual(payload.title, "小满 · 第 120 天 · 吉卜力风 #宝宝成长")
        XCTAssertEqual(payload.description, "")
        XCTAssertEqual(payload.mediaKind, .image)
        XCTAssertEqual(payload.mediaURL, imageURL)
        XCTAssertLessThanOrEqual(payload.thumbData.count, WechatThumbnailAdapter.defaultMaxBytes)
    }

    func testShareToSessionUsesTitleAndDescription() async throws {
        let imageURL = try writeSolidImage(named: "share.jpg")
        let asset = SharePreparedAsset(
            mediaURL: imageURL,
            thumbnailURL: nil,
            mediaKind: .image,
            appliedDeepSynthesisBadge: false,
            appliedBrandWatermark: true
        )
        let bridge = SpyWechatOpenSDKBridge()
        let adapter = WechatShareAdapter(bridge: bridge)
        let caption = "第一行标题\n第二行详情 #话题"

        try await adapter.share(
            WechatShareRequest(asset: asset, caption: caption, scene: .session)
        )

        let payload = try XCTUnwrap(bridge.lastPayload)
        XCTAssertEqual(payload.scene, .session)
        XCTAssertEqual(payload.title, "第一行标题")
        XCTAssertEqual(payload.description, caption)
    }

    func testShareVideoUsesPreparedThumbnail() async throws {
        let videoURL = tempRoot.appendingPathComponent("clip.mp4")
        try Data("video".utf8).write(to: videoURL)
        let thumbURL = try writeSolidImage(named: "thumb.jpg")
        let asset = SharePreparedAsset(
            mediaURL: videoURL,
            thumbnailURL: thumbURL,
            mediaKind: .video,
            appliedDeepSynthesisBadge: true,
            appliedBrandWatermark: false
        )
        let bridge = SpyWechatOpenSDKBridge()
        let adapter = WechatShareAdapter(bridge: bridge)

        try await adapter.share(
            WechatShareRequest(
                asset: asset,
                caption: "成长视频",
                scene: .session
            )
        )

        let payload = try XCTUnwrap(bridge.lastPayload)
        XCTAssertEqual(payload.mediaKind, .video)
        XCTAssertEqual(payload.mediaURL, videoURL)
        XCTAssertFalse(payload.thumbData.isEmpty)
        XCTAssertLessThanOrEqual(payload.thumbData.count, WechatThumbnailAdapter.defaultMaxBytes)
    }

    func testShareFailsWhenWechatNotInstalled() async throws {
        let imageURL = try writeSolidImage(named: "share.jpg")
        let asset = SharePreparedAsset(
            mediaURL: imageURL,
            thumbnailURL: nil,
            mediaKind: .image,
            appliedDeepSynthesisBadge: false,
            appliedBrandWatermark: false
        )
        let adapter = WechatShareAdapter(bridge: StubWechatOpenSDKBridge(isWechatInstalled: false))

        do {
            try await adapter.share(
                WechatShareRequest(asset: asset, caption: "文案", scene: .timeline)
            )
            XCTFail("Expected wechatNotInstalled")
        } catch let error as WechatShareError {
            XCTAssertEqual(error, .wechatNotInstalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testShareFailsWhenUniversalLinkInvalid() async throws {
        let imageURL = try writeSolidImage(named: "share.jpg")
        let asset = SharePreparedAsset(
            mediaURL: imageURL,
            thumbnailURL: nil,
            mediaKind: .image,
            appliedDeepSynthesisBadge: false,
            appliedBrandWatermark: false
        )
        let adapter = WechatShareAdapter(
            configuration: WechatShareConfiguration(universalLink: "http://bad-link")
        )

        do {
            try await adapter.share(
                WechatShareRequest(asset: asset, caption: "文案", scene: .timeline)
            )
            XCTFail("Expected invalidUniversalLink")
        } catch let error as WechatShareError {
            XCTAssertEqual(error, .invalidUniversalLink("http://bad-link"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testShareFailsWhenVideoThumbnailMissing() async throws {
        let videoURL = tempRoot.appendingPathComponent("clip.mp4")
        try Data("video".utf8).write(to: videoURL)
        let asset = SharePreparedAsset(
            mediaURL: videoURL,
            thumbnailURL: nil,
            mediaKind: .video,
            appliedDeepSynthesisBadge: true,
            appliedBrandWatermark: false
        )
        let adapter = WechatShareAdapter()

        do {
            try await adapter.share(
                WechatShareRequest(asset: asset, caption: "视频", scene: .timeline)
            )
            XCTFail("Expected thumbnailAdaptationFailed")
        } catch let error as WechatShareError {
            XCTAssertEqual(error, .thumbnailAdaptationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testThumbnailAdapterCompressesLargeImageUnderLimit() throws {
        let imageURL = try writeSolidImage(
            named: "large.jpg",
            width: 2048,
            height: 1536
        )
        let asset = SharePreparedAsset(
            mediaURL: imageURL,
            thumbnailURL: nil,
            mediaKind: .image,
            appliedDeepSynthesisBadge: false,
            appliedBrandWatermark: false
        )
        let adapter = WechatThumbnailAdapter()

        let thumbData = try adapter.makeThumbData(from: asset)

        XCTAssertLessThanOrEqual(thumbData.count, WechatThumbnailAdapter.defaultMaxBytes)
        let decoded = try codec.decode(data: thumbData)
        XCTAssertLessThanOrEqual(max(decoded.width, decoded.height), WechatThumbnailAdapter.defaultMaxEdgeLength)
    }

    func testStubBridgeDoesNotCallRealSDK() async throws {
        let imageURL = try writeSolidImage(named: "share.jpg")
        let asset = SharePreparedAsset(
            mediaURL: imageURL,
            thumbnailURL: nil,
            mediaKind: .image,
            appliedDeepSynthesisBadge: false,
            appliedBrandWatermark: false
        )
        let stub = StubWechatOpenSDKBridge()

        try await WechatShareAdapter(bridge: stub).share(
            WechatShareRequest(asset: asset, caption: "stub ok", scene: .timeline)
        )
    }

    private func writeSolidImage(
        named fileName: String,
        width: Int = 640,
        height: Int = 480
    ) throws -> URL {
        let image = TestImageFactory.makeSolidColorImage(width: width, height: height, color: .blue)
        let encoded = try codec.encode(image: image, format: .jpeg)
        let url = tempRoot.appendingPathComponent(fileName)
        try encoded.data.write(to: url)
        return url
    }
}

private final class SpyWechatOpenSDKBridge: WechatOpenSDKBridging, @unchecked Sendable {
    private(set) var lastPayload: WechatSharePayload?

    var isWechatInstalled: Bool { true }

    func send(_ payload: WechatSharePayload) async throws {
        lastPayload = payload
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
