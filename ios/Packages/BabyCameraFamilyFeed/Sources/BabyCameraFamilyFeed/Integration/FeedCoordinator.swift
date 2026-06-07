import BabyCameraBaby
import BabyCameraNetwork
import Foundation

public enum FeedCoordinatorError: Error, Equatable, Sendable {
    case publishFailed(String)
    case postNotFound(String)
    case withdrawForbidden(String)
}

/// T5.19 家庭圈联调协调器：发布 → Feed 刷新 → 点赞评论 → 撤回 全链路编排。
@MainActor
public final class FeedCoordinator: ObservableObject {
    public let context: FeedIntegrationContext
    public private(set) var feedListViewModel: FeedListViewModel?
    @Published public private(set) var lastPublishedPostId: String?
    @Published public private(set) var lastWithdrawnPostId: String?

    private let currentBabyEnvironment: CurrentBabyEnvironment
    private let mentionCandidates: [FeedMentionCandidate]

    public init(
        context: FeedIntegrationContext,
        currentBabyEnvironment: CurrentBabyEnvironment,
        mentionCandidates: [FeedMentionCandidate] = []
    ) {
        self.context = context
        self.currentBabyEnvironment = currentBabyEnvironment
        self.mentionCandidates = mentionCandidates
    }

    /// 创建并绑定 Feed 列表 ViewModel（含 WS 订阅生命周期）。
    @discardableResult
    public func attachFeedList() -> FeedListViewModel {
        let viewModel = FamilyFeedIntegration.makeFeedListViewModel(
            context: context,
            currentBabyEnvironment: currentBabyEnvironment,
            mentionCandidates: mentionCandidates
        )
        feedListViewModel = viewModel
        return viewModel
    }

    /// 发布动态并在成功后刷新 Feed 列表。
    @discardableResult
    public func publish(composer: PostComposerViewModel) async throws -> PostCreateData {
        await composer.publish()

        switch composer.phase {
        case let .published(data):
            lastPublishedPostId = data.postId
            if feedListViewModel == nil {
                attachFeedList()
            }
            await feedListViewModel?.reload()
            return data
        case let .failed(message):
            throw FeedCoordinatorError.publishFailed(message)
        case .editing, .publishing:
            throw FeedCoordinatorError.publishFailed("发布未完成")
        }
    }

    /// 对指定动态点赞（双击或按钮）。
    public func like(post: FeedPost) async throws {
        if feedListViewModel == nil {
            attachFeedList()
        }
        await feedListViewModel?.doubleTapLike(post: post)
    }

    /// 发表评论（需先 `beginComment` 设置草稿）。
    public func submitComment(on post: FeedPost, text: String) async throws {
        if feedListViewModel == nil {
            attachFeedList()
        }
        feedListViewModel?.beginComment(on: post)
        feedListViewModel?.commentDraft = text
        await feedListViewModel?.submitComment()
    }

    /// 撤回已发布动态并从 Feed 列表移除。
    @discardableResult
    public func withdraw(postId: String) async throws -> PostDeleteData {
        let trimmed = postId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FeedCoordinatorError.postNotFound(postId)
        }

        do {
            let result = try await context.postService.withdraw(postId: trimmed)
            lastWithdrawnPostId = trimmed
            feedListViewModel?.removePostLocally(postId: trimmed)
            await feedListViewModel?.reload()
            return result
        } catch let apiError as APIError where apiError.code == .commonNotFound {
            throw FeedCoordinatorError.postNotFound(trimmed)
        } catch let apiError as APIError where apiError.code == .commonForbidden {
            throw FeedCoordinatorError.withdrawForbidden(apiError.message)
        } catch {
            throw error
        }
    }
}
