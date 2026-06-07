import BabyCameraNetwork
import Database
import Foundation

public struct PostPublishContext: Sendable, Equatable {
    public let familyId: String
    public let babyIds: [String]
    public let caption: String
    public let visibility: PostVisibility
    public let items: [PostComposerMediaItem]

    public init(
        familyId: String,
        babyIds: [String],
        caption: String,
        visibility: PostVisibility,
        items: [PostComposerMediaItem]
    ) {
        self.familyId = familyId
        self.babyIds = babyIds
        self.caption = caption
        self.visibility = visibility
        self.items = items
    }
}

public protocol PostServing: Sendable {
    func publish(_ context: PostPublishContext) async throws -> PostCreateData
    func withdraw(postId: String) async throws -> PostDeleteData
}

/// 默认发布服务：将已上传 objectKey 的媒体提交至 feed-svc。
public struct PostService: PostServing {
    private let postsAPI: PostsAPI
    private let cacheRepository: (any FeedCacheRepository)?

    public init(postsAPI: PostsAPI, cacheRepository: (any FeedCacheRepository)? = nil) {
        self.postsAPI = postsAPI
        self.cacheRepository = cacheRepository
    }

    public func publish(_ context: PostPublishContext) async throws -> PostCreateData {
        let createItems = context.items.compactMap { $0.toCreateItem() }
        guard createItems.count == context.items.count else {
            throw PostServiceError.itemsNotReady
        }

        let request = PostCreateRequest(
            familyId: context.familyId,
            babyIds: context.babyIds,
            caption: context.caption,
            visibility: context.visibility,
            items: createItems
        )
        return try await postsAPI.create(request)
    }

    public func withdraw(postId: String) async throws -> PostDeleteData {
        let trimmed = postId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PostServiceError.postIdMissing
        }

        let result = try await postsAPI.delete(postId: trimmed)
        if let cacheRepository {
            try await cacheRepository.deletePost(id: trimmed)
        }
        return result
    }
}

public enum PostServiceError: Error, Equatable, Sendable {
    case itemsNotReady
    case postIdMissing
}
