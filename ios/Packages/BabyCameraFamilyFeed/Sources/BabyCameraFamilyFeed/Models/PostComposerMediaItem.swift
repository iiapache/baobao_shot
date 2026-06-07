import BabyCameraNetwork
import Foundation

/// 发布编辑器中的本地媒体草稿。
public struct PostComposerMediaItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: PostItemKind
    public let localURL: URL?
    public let previewData: Data?
    public let width: Int
    public let height: Int
    public let deepSynth: Bool
    public var objectKey: String?

    public init(
        id: String = UUID().uuidString,
        kind: PostItemKind,
        localURL: URL? = nil,
        previewData: Data? = nil,
        width: Int,
        height: Int,
        deepSynth: Bool = false,
        objectKey: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.localURL = localURL
        self.previewData = previewData
        self.width = width
        self.height = height
        self.deepSynth = deepSynth
        self.objectKey = objectKey
    }

    public func toCreateItem() -> PostCreateItem? {
        guard let objectKey else { return nil }
        return PostCreateItem(
            kind: kind,
            objectKey: objectKey,
            width: width,
            height: height,
            deepSynth: deepSynth
        )
    }
}
