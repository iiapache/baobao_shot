import Foundation

/// 单张导入请求。
public struct ImportRequest: Sendable {
    public let babyIds: [String]
    public let babies: [BabyMetadataInput]
    public let userId: String

    public init(babyIds: [String], babies: [BabyMetadataInput], userId: String) {
        self.babyIds = babyIds
        self.babies = babies
        self.userId = userId
    }
}

/// 单张导入成功结果。
public struct ImportResult: Sendable, Equatable {
    public let photoId: String
    public let takenAt: Date
    public let fileURL: URL

    public init(photoId: String, takenAt: Date, fileURL: URL) {
        self.photoId = photoId
        self.takenAt = takenAt
        self.fileURL = fileURL
    }
}

/// 批量导入汇总。
public struct ImportBatchResult: Sendable, Equatable {
    public let succeeded: [ImportResult]
    public let failed: [ImportFailure]

    public init(succeeded: [ImportResult], failed: [ImportFailure]) {
        self.succeeded = succeeded
        self.failed = failed
    }
}

/// 单张导入失败明细。
public struct ImportFailure: Sendable, Equatable {
    public let item: PickerImportItem
    public let error: ImportError

    public init(item: PickerImportItem, error: ImportError) {
        self.item = item
        self.error = error
    }
}

/// PHPicker 选中项的协议抽象（便于单测，不依赖 PhotosUI）。
public struct PickerImportItem: Sendable, Equatable, Identifiable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
