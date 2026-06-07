import Foundation

public enum PostComposerValidationError: Equatable, Sendable {
    case imageLimitExceeded(current: Int, max: Int)
    case videoLimitExceeded(current: Int, max: Int)
    case emptyContent
    case captionTooLong(current: Int, max: Int)
    case itemsNotUploaded(missingCount: Int)
}

public struct PostComposerValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let errors: [PostComposerValidationError]

    public init(isValid: Bool, errors: [PostComposerValidationError]) {
        self.isValid = isValid
        self.errors = errors
    }

    public static let valid = PostComposerValidationResult(isValid: true, errors: [])
}

/// 发布编辑器校验逻辑（T5.10 验收：超数量校验）。
public enum PostComposerValidator {
    public static let maxCaptionLength = 500

    public static func validate(
        caption: String,
        items: [PostComposerMediaItem],
        requireUploadedObjectKeys: Bool = false
    ) -> PostComposerValidationResult {
        var errors: [PostComposerValidationError] = []

        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageCount = PostMediaLimits.imageCount(in: items)
        let videoCount = PostMediaLimits.videoCount(in: items)

        if imageCount > PostMediaLimits.maxImages {
            errors.append(.imageLimitExceeded(current: imageCount, max: PostMediaLimits.maxImages))
        }
        if videoCount > PostMediaLimits.maxVideos {
            errors.append(.videoLimitExceeded(current: videoCount, max: PostMediaLimits.maxVideos))
        }
        if items.isEmpty && trimmedCaption.isEmpty {
            errors.append(.emptyContent)
        }
        if caption.count > maxCaptionLength {
            errors.append(.captionTooLong(current: caption.count, max: maxCaptionLength))
        }
        if requireUploadedObjectKeys {
            let missing = items.filter { $0.objectKey == nil }.count
            if missing > 0 {
                errors.append(.itemsNotUploaded(missingCount: missing))
            }
        }

        return PostComposerValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    public static func validateAddingImage(to items: [PostComposerMediaItem]) -> PostComposerValidationResult {
        let nextCount = PostMediaLimits.imageCount(in: items) + 1
        if nextCount > PostMediaLimits.maxImages {
            return PostComposerValidationResult(
                isValid: false,
                errors: [.imageLimitExceeded(current: nextCount, max: PostMediaLimits.maxImages)]
            )
        }
        return .valid
    }

    public static func validateAddingVideo(to items: [PostComposerMediaItem]) -> PostComposerValidationResult {
        let nextCount = PostMediaLimits.videoCount(in: items) + 1
        if nextCount > PostMediaLimits.maxVideos {
            return PostComposerValidationResult(
                isValid: false,
                errors: [.videoLimitExceeded(current: nextCount, max: PostMediaLimits.maxVideos)]
            )
        }
        return .valid
    }

    public static func message(for error: PostComposerValidationError) -> String {
        switch error {
        case let .imageLimitExceeded(current, max):
            return "最多添加 \(max) 张图片（当前 \(current) 张）"
        case let .videoLimitExceeded(current, max):
            return "最多添加 \(max) 个视频（当前 \(current) 个）"
        case .emptyContent:
            return "请添加图片、视频或文案"
        case let .captionTooLong(current, max):
            return "文案过长（\(current)/\(max)）"
        case let .itemsNotUploaded(missingCount):
            return "还有 \(missingCount) 个媒体未上传完成"
        }
    }
}
