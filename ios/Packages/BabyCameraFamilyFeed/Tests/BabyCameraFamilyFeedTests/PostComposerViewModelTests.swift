import BabyCameraBaby
import BabyCameraImageKit
import BabyCameraNetwork
import BabyCameraWatermark
import CoreGraphics
import UIKit
import XCTest
@testable import BabyCameraFamilyFeed

@MainActor
final class PostComposerViewModelTests: XCTestCase {
    func testInitialCaptionUsesDefaultTemplate() {
        let viewModel = makeViewModel(aiPlayName: "吉卜力风")
        XCTAssertEqual(viewModel.caption, "豆豆 · 第 10 天 · 吉卜力风")
    }

    func testAddImageRespectsNineImageLimit() {
        let viewModel = makeViewModel()
        for index in 0..<9 {
            XCTAssertTrue(viewModel.addImage(makeImageItem(id: "img_\(index)")))
        }
        XCTAssertFalse(viewModel.addImage(makeImageItem(id: "img_overflow")))
        XCTAssertEqual(viewModel.validationErrors.first, .imageLimitExceeded(current: 10, max: 9))
    }

    func testAddVideoRespectsOneVideoLimit() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.addVideo(makeVideoItem(id: "vid_1")))
        XCTAssertFalse(viewModel.addVideo(makeVideoItem(id: "vid_2")))
        XCTAssertEqual(viewModel.validationErrors.first, .videoLimitExceeded(current: 2, max: 1))
    }

    func testRefreshWatermarkPreviewUsesRenderer() async throws {
        let sourceData = try makeSolidJPEGData()
        let viewModel = makeViewModel(watermarkPreview: SpyWatermarkPreview(resultSize: CGSize(width: 32, height: 32)))
        viewModel.addImage(
            PostComposerMediaItem(
                kind: .image,
                previewData: sourceData,
                width: 32,
                height: 32,
                deepSynth: true
            )
        )

        await viewModel.refreshWatermarkPreview()

        XCTAssertNotNil(viewModel.watermarkPreviewImage)
        XCTAssertEqual(viewModel.watermarkPreviewImage?.size, CGSize(width: 32, height: 32))
    }

    func testPublishRequiresUploadedObjectKeys() async {
        let service = SpyPostService()
        let viewModel = makeViewModel(postService: service)
        viewModel.addImage(makeImageItem(id: "img_1"))
        viewModel.caption = "发布测试"

        await viewModel.publish()

        if case .failed = viewModel.phase {
            // expected
        } else {
            XCTFail("expected failed phase")
        }
        XCTAssertEqual(service.publishCallCount, 0)
    }

    func testPublishSuccess() async {
        let service = SpyPostService()
        let viewModel = makeViewModel(postService: service)
        var item = makeImageItem(id: "img_1")
        viewModel.addImage(item)
        viewModel.updateObjectKey(for: item.id, objectKey: "family/fam/post/1.heic")

        await viewModel.publish()

        if case let .published(data) = viewModel.phase {
            XCTAssertEqual(data.postId, "pst_mock")
        } else {
            XCTFail("expected published phase")
        }
        XCTAssertEqual(service.publishCallCount, 1)
    }

    func testGenerateSmartCaptionsShowsPickerOnSuccess() async {
        let captionService = SpyCaptionService(
            outcome: .success(
                candidates: [
                    CaptionCandidate(text: "候选 A", hashtags: ["#A"]),
                    CaptionCandidate(text: "候选 B", hashtags: []),
                    CaptionCandidate(text: "候选 C", hashtags: []),
                ],
                remainingToday: 7
            )
        )
        let viewModel = makeViewModel(captionService: captionService)

        await viewModel.generateSmartCaptions()

        XCTAssertTrue(viewModel.showCaptionPicker)
        if case let .ready(candidates, remainingToday) = viewModel.captionPickerPhase {
            XCTAssertEqual(candidates.count, 3)
            XCTAssertEqual(remainingToday, 7)
        } else {
            XCTFail("expected ready phase")
        }
        XCTAssertEqual(captionService.generateCallCount, 1)
    }

    func testSelectCaptionCandidateUpdatesCaption() async {
        let captionService = SpyCaptionService(
            outcome: .success(
                candidates: [CaptionCandidate(text: "选中我", hashtags: ["#宝宝"])],
                remainingToday: 1
            )
        )
        let viewModel = makeViewModel(captionService: captionService)
        await viewModel.generateSmartCaptions()

        viewModel.selectCaptionCandidate(CaptionCandidate(text: "选中我", hashtags: ["#宝宝"]))

        XCTAssertEqual(viewModel.caption, "选中我 #宝宝")
        XCTAssertFalse(viewModel.showCaptionPicker)
        XCTAssertEqual(viewModel.captionPickerPhase, .idle)
    }

    func testGenerateSmartCaptionsDailyLimitShowsNoticeAndFallback() async {
        let captionService = SpyCaptionService(
            outcome: .dailyLimitExceeded(
                message: CaptionService.dailyLimitMessage,
                fallbackCaption: "豆豆 · 第 10 天 · 吉卜力风"
            )
        )
        let viewModel = makeViewModel(aiPlayName: "吉卜力风", captionService: captionService)

        await viewModel.generateSmartCaptions()

        XCTAssertFalse(viewModel.showCaptionPicker)
        XCTAssertEqual(viewModel.caption, "豆豆 · 第 10 天 · 吉卜力风")
        XCTAssertEqual(viewModel.captionNotice, CaptionService.dailyLimitMessage)
        if case let .limitExceeded(message) = viewModel.captionPickerPhase {
            XCTAssertEqual(message, CaptionService.dailyLimitMessage)
        } else {
            XCTFail("expected limitExceeded phase")
        }
    }

    func testGenerateSmartCaptionsWithoutServiceDegradesToTemplate() async {
        let viewModel = makeViewModel(aiPlayName: "吉卜力风", captionService: nil)

        await viewModel.generateSmartCaptions()

        XCTAssertEqual(viewModel.caption, "豆豆 · 第 10 天 · 吉卜力风")
        XCTAssertEqual(viewModel.captionPickerPhase, .degraded)
        XCTAssertFalse(viewModel.canGenerateSmartCaptions)
    }

    private func makeViewModel(
        aiPlayName: String? = nil,
        postService: (any PostServing)? = nil,
        captionService: (any CaptionServing)? = nil,
        watermarkPreview: (any PostWatermarkPreviewing)? = nil
    ) -> PostComposerViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let referenceDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10))!

        return PostComposerViewModel(
            baby: BabyProfile(
                id: "bb_test",
                familyId: "fam_test",
                name: "豆豆",
                birthDate: "2024-01-01"
            ),
            aiPlayName: aiPlayName,
            postService: postService ?? SpyPostService(),
            captionService: captionService,
            watermarkPreview: watermarkPreview ?? SpyWatermarkPreview(resultSize: CGSize(width: 8, height: 8)),
            referenceDate: referenceDate
        )
    }

    private func makeImageItem(id: String) -> PostComposerMediaItem {
        PostComposerMediaItem(id: id, kind: .image, width: 100, height: 100)
    }

    private func makeVideoItem(id: String) -> PostComposerMediaItem {
        PostComposerMediaItem(id: id, kind: .video, width: 1920, height: 1080)
    }

    private func makeSolidJPEGData() throws -> Data {
        let codec = ImageCodec()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 32,
            height: 32,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "test", code: 1)
        }
        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        guard let image = context.makeImage() else {
            throw NSError(domain: "test", code: 2)
        }
        return try codec.encode(image: image, format: .jpeg).data
    }
}

private final class SpyCaptionService: CaptionServing, @unchecked Sendable {
    let outcome: CaptionGenerationOutcome
    private(set) var generateCallCount = 0

    init(outcome: CaptionGenerationOutcome = .degraded(fallbackCaption: "")) {
        self.outcome = outcome
    }

    func generate(_ input: CaptionGenerateInput) async -> CaptionGenerationOutcome {
        generateCallCount += 1
        return outcome
    }
}

private final class SpyPostService: PostServing, @unchecked Sendable {
    private(set) var publishCallCount = 0
    private(set) var withdrawCallCount = 0

    func publish(_ context: PostPublishContext) async throws -> PostCreateData {
        publishCallCount += 1
        return PostCreateData(postId: "pst_mock", status: "published", createdAt: "2026-06-06T10:00:00Z")
    }

    func withdraw(postId: String) async throws -> PostDeleteData {
        withdrawCallCount += 1
        return PostDeleteData(postId: postId, status: "removed", deletedAt: "2026-06-06T11:00:00Z")
    }
}

private struct SpyWatermarkPreview: PostWatermarkPreviewing {
    let resultSize: CGSize

    func previewCGImage(
        sourceData: Data,
        isSubscribed: Bool,
        includesDeepSynthesisBadge: Bool
    ) throws -> CGImage {
        let width = Int(resultSize.width)
        let height = Int(resultSize.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw PostWatermarkPreviewError.renderFailed
        }
        return image
    }
}
