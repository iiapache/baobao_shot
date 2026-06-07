import Database
import Foundation

public struct AITaskDownloadContext: Sendable, Equatable {
    public let sourcePhotoId: String
    public let babyId: String
    public let playKind: AIPlayKind
    public let style: String?
    public let model: String?
    public let costCredits: Int
    public let sourceUrl: String

    public init(
        sourcePhotoId: String,
        babyId: String,
        playKind: AIPlayKind,
        style: String? = nil,
        model: String? = nil,
        costCredits: Int = 0,
        sourceUrl: String
    ) {
        self.sourcePhotoId = sourcePhotoId
        self.babyId = babyId
        self.playKind = playKind
        self.style = style
        self.model = model
        self.costCredits = costCredits
        self.sourceUrl = sourceUrl
    }
}

public struct AITaskDownloadRequest: Sendable, Equatable {
    public let taskId: String
    public let resultUrl: String
    public let context: AITaskDownloadContext

    public init(taskId: String, resultUrl: String, context: AITaskDownloadContext) {
        self.taskId = taskId
        self.resultUrl = resultUrl
        self.context = context
    }
}

public struct AITaskDownloadResult: Sendable, Equatable {
    public let taskId: String
    public let derivedId: String
    public let filePath: String
    public let derivedKind: DerivedAssetKind
    public let thumbnailPath: String?

    public init(
        taskId: String,
        derivedId: String,
        filePath: String,
        derivedKind: DerivedAssetKind,
        thumbnailPath: String? = nil
    ) {
        self.taskId = taskId
        self.derivedId = derivedId
        self.filePath = filePath
        self.derivedKind = derivedKind
        self.thumbnailPath = thumbnailPath
    }
}
