import BabyCameraBaby
import BabyCameraNetwork
import Foundation
import UIKit

public enum PostComposerPhase: Equatable {
    case editing
    case publishing
    case published(PostCreateData)
    case failed(String)
}

public enum CaptionPickerPhase: Equatable {
    case idle
    case loading
    case ready(candidates: [CaptionCandidate], remainingToday: Int)
    case limitExceeded(message: String)
    case degraded
}

@MainActor
public final class PostComposerViewModel: ObservableObject {
    @Published public var caption: String
    @Published public var visibility: PostVisibility
    @Published public private(set) var mediaItems: [PostComposerMediaItem] = []
    @Published public private(set) var phase: PostComposerPhase = .editing
    @Published public private(set) var validationErrors: [PostComposerValidationError] = []
    @Published public private(set) var watermarkPreviewImage: UIImage?
    @Published public private(set) var isRefreshingWatermarkPreview = false
    @Published public private(set) var captionPickerPhase: CaptionPickerPhase = .idle
    @Published public var showCaptionPicker = false
    @Published public private(set) var captionNotice: String?

    public let baby: BabyProfile
    public let aiPlayName: String?
    public let aiPlayId: String?
    public let isSubscribed: Bool

    private let postService: any PostServing
    private let captionService: (any CaptionServing)?
    private let watermarkPreview: any PostWatermarkPreviewing
    private let referenceDate: Date

    public init(
        baby: BabyProfile,
        aiPlayName: String? = nil,
        aiPlayId: String? = nil,
        isSubscribed: Bool = false,
        initialCaption: String? = nil,
        visibility: PostVisibility = .family,
        postService: any PostServing,
        captionService: (any CaptionServing)? = nil,
        watermarkPreview: any PostWatermarkPreviewing = PostComposerWatermarkPreview(),
        referenceDate: Date = Date()
    ) {
        self.baby = baby
        self.aiPlayName = aiPlayName
        self.aiPlayId = aiPlayId
        self.isSubscribed = isSubscribed
        self.visibility = visibility
        self.postService = postService
        self.captionService = captionService
        self.watermarkPreview = watermarkPreview
        self.referenceDate = referenceDate

        if let initialCaption {
            self.caption = initialCaption
        } else {
            self.caption = PostCaptionTemplate.makeCaption(
                babyName: baby.name,
                birthDate: baby.birthDate,
                aiPlayName: aiPlayName,
                referenceDate: referenceDate
            )
        }
    }

    public var canAddImage: Bool {
        PostMediaLimits.canAddImage(currentItems: mediaItems)
    }

    public var canAddVideo: Bool {
        PostMediaLimits.canAddVideo(currentItems: mediaItems)
    }

    public var remainingImageSlots: Int {
        PostMediaLimits.remainingImageSlots(in: mediaItems)
    }

    public var remainingVideoSlots: Int {
        PostMediaLimits.remainingVideoSlots(in: mediaItems)
    }

    public var isPublishing: Bool {
        if case .publishing = phase { return true }
        return false
    }

    public var canPublish: Bool {
        PostComposerValidator.validate(caption: caption, items: mediaItems).isValid
    }

    public var validationMessage: String? {
        validationErrors.first.map(PostComposerValidator.message(for:))
    }

    public func applyDefaultCaption() {
        caption = PostCaptionTemplate.makeCaption(
            babyName: baby.name,
            birthDate: baby.birthDate,
            aiPlayName: aiPlayName,
            referenceDate: referenceDate
        )
        captionNotice = nil
        captionPickerPhase = .idle
    }

    public var isGeneratingCaptions: Bool {
        if case .loading = captionPickerPhase { return true }
        return false
    }

    public var canGenerateSmartCaptions: Bool {
        captionService != nil
    }

    public func generateSmartCaptions() async {
        captionNotice = nil
        captionPickerPhase = .loading

        guard let captionService else {
            applyDefaultCaption()
            captionPickerPhase = .degraded
            return
        }

        let input = CaptionGenerateInput(
            babyId: baby.id,
            babyName: baby.name,
            birthDate: baby.birthDate,
            aiPlayId: aiPlayId,
            aiPlayName: aiPlayName,
            referenceDate: referenceDate
        )
        let outcome = await captionService.generate(input)

        switch outcome {
        case let .success(candidates, remainingToday):
            captionPickerPhase = .ready(candidates: candidates, remainingToday: remainingToday)
            showCaptionPicker = true
        case let .dailyLimitExceeded(message, fallbackCaption):
            caption = fallbackCaption
            captionNotice = message
            captionPickerPhase = .limitExceeded(message: message)
            showCaptionPicker = false
        case let .degraded(fallbackCaption):
            caption = fallbackCaption
            captionPickerPhase = .degraded
            showCaptionPicker = false
        }
    }

    public func selectCaptionCandidate(_ candidate: CaptionCandidate) {
        caption = candidate.composedText
        captionNotice = nil
        captionPickerPhase = .idle
        showCaptionPicker = false
    }

    public func dismissCaptionPicker() {
        showCaptionPicker = false
        if case .ready = captionPickerPhase {
            captionPickerPhase = .idle
        }
    }

    @discardableResult
    public func addImage(_ item: PostComposerMediaItem) -> Bool {
        let result = PostComposerValidator.validateAddingImage(to: mediaItems)
        guard result.isValid, item.kind == .image else {
            validationErrors = result.errors
            return false
        }
        mediaItems.append(item)
        validationErrors = []
        Task { await refreshWatermarkPreview() }
        return true
    }

    @discardableResult
    public func addVideo(_ item: PostComposerMediaItem) -> Bool {
        let result = PostComposerValidator.validateAddingVideo(to: mediaItems)
        guard result.isValid, item.kind == .video else {
            validationErrors = result.errors
            return false
        }
        mediaItems.append(item)
        validationErrors = []
        return true
    }

    public func removeMedia(id: String) {
        mediaItems.removeAll { $0.id == id }
        validationErrors = []
        Task { await refreshWatermarkPreview() }
    }

    public func updateObjectKey(for itemId: String, objectKey: String) {
        guard let index = mediaItems.firstIndex(where: { $0.id == itemId }) else { return }
        mediaItems[index].objectKey = objectKey
    }

    public func refreshValidation() {
        validationErrors = PostComposerValidator.validate(caption: caption, items: mediaItems).errors
    }

    public func refreshWatermarkPreview() async {
        guard let firstImage = mediaItems.first(where: { $0.kind == .image }),
              let previewData = firstImage.previewData else {
            watermarkPreviewImage = nil
            return
        }

        isRefreshingWatermarkPreview = true
        defer { isRefreshingWatermarkPreview = false }

        do {
            let cgImage = try watermarkPreview.previewCGImage(
                sourceData: previewData,
                isSubscribed: isSubscribed,
                includesDeepSynthesisBadge: firstImage.deepSynth
            )
            watermarkPreviewImage = UIImage(cgImage: cgImage)
        } catch {
            watermarkPreviewImage = nil
        }
    }

    public func publish() async {
        let validation = PostComposerValidator.validate(
            caption: caption,
            items: mediaItems,
            requireUploadedObjectKeys: true
        )
        validationErrors = validation.errors
        guard validation.isValid else {
            phase = .failed(validation.errors.first.map(PostComposerValidator.message(for:)) ?? "无法发布")
            return
        }

        phase = .publishing
        let context = PostPublishContext(
            familyId: baby.familyId,
            babyIds: [baby.id],
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            visibility: visibility,
            items: mediaItems
        )

        do {
            let result = try await postService.publish(context)
            phase = .published(result)
            validationErrors = []
        } catch let apiError as APIError where apiError.code == .postItemLimit {
            validationErrors = [.imageLimitExceeded(
                current: PostMediaLimits.imageCount(in: mediaItems),
                max: PostMediaLimits.maxImages
            )]
            phase = .failed(PostComposerValidator.message(for: validationErrors[0]))
        } catch {
            phase = .failed(mapError(error))
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        if let serviceError = error as? PostServiceError, serviceError == .itemsNotReady {
            return "媒体尚未上传完成"
        }
        return error.localizedDescription
    }
}
