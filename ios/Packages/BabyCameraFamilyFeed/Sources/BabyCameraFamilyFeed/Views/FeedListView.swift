import BabyCameraBaby
import BabyCameraNetwork
import DesignSystem
import SwiftUI

/// 家庭圈 Feed 列表（T5.11 分页缓存 + T5.12 双击点赞 / 长按评论 / 未读红点）。
public struct FeedListView: View {
    @EnvironmentObject private var networkReachability: NetworkReachability
    @ObservedObject private var viewModel: FeedListViewModel
    @ObservedObject private var currentBabyEnvironment: CurrentBabyEnvironment
    @State private var networkWasOffline = false
    @State private var reconnectHandlerId: UUID?
    private let isEngagementAllowed: Bool
    private let onEngagementBlocked: (() -> Void)?

    public init(
        viewModel: FeedListViewModel,
        currentBabyEnvironment: CurrentBabyEnvironment,
        isEngagementAllowed: Bool = true,
        onEngagementBlocked: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.currentBabyEnvironment = currentBabyEnvironment
        self.isEngagementAllowed = isEngagementAllowed
        self.onEngagementBlocked = onEngagementBlocked
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                DSLoadingView(message: "加载动态…", style: .fullScreen)
            } else if viewModel.posts.isEmpty, let errorMessage = viewModel.errorMessage {
                DSErrorView(
                    kind: .network,
                    title: "无法加载动态",
                    message: errorMessage,
                    actionTitle: "重试"
                ) {
                    Task { await viewModel.reload() }
                }
            } else if viewModel.posts.isEmpty {
                DSEmptyState(
                    systemImage: "photo.on.rectangle.angled",
                    title: "暂无动态",
                    message: "家人发布的照片和视频会显示在这里"
                )
            } else {
                listContent
            }
        }
        .accessibilityIdentifier("feedListView")
        .navigationTitle("家庭圈")
        .toolbar {
            if viewModel.totalUnreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    FeedUnreadBadge(count: viewModel.totalUnreadCount)
                }
            }
        }
        .overlay(alignment: .top) {
            if showsOfflineBanner {
                DSOfflineBanner(message: offlineBannerMessage)
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .onAppear {
            reconnectHandlerId = networkReachability.onReconnect { [viewModel] in
                Task { await viewModel.reload() }
            }
        }
        .onDisappear {
            viewModel.onDisappear()
            if let reconnectHandlerId {
                networkReachability.removeReconnectHandler(reconnectHandlerId)
            }
        }
        .onChange(of: networkReachability.isOnline) { isOnline in
            if isOnline, networkWasOffline {
                Task { await viewModel.reload() }
            }
            networkWasOffline = !isOnline
        }
        .onChange(of: currentBabyEnvironment.currentBabyId) { _ in
            Task { await viewModel.applyBabyFilter() }
        }
        .sheet(
            isPresented: Binding(
                get: { isEngagementAllowed && viewModel.commentComposerPostId != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.cancelComment()
                    }
                }
            )
        ) {
            FeedCommentComposerView(
                draft: $viewModel.commentDraft,
                mentionCandidates: viewModel.mentionCandidates,
                onSubmit: {
                    Task { await viewModel.submitComment() }
                },
                onCancel: {
                    viewModel.cancelComment()
                }
            )
        }
    }

    private var showsOfflineBanner: Bool {
        viewModel.isOffline || !networkReachability.isOnline
    }

    private var offlineBannerMessage: String {
        if viewModel.isOffline {
            return "离线模式 · 显示最近缓存"
        }
        return "当前无网络 · 显示最近缓存"
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.posts) { post in
                FeedPostRow(
                    caption: viewModel.displayCaption(for: post),
                    createdAt: post.createdAt,
                    mediaCount: post.mediaItems.count,
                    hasVideo: post.mediaItems.contains { $0.kind == "video" },
                    engagement: viewModel.engagement(for: post.postId),
                    showLikeAnimation: viewModel.showLikeAnimationPostId == post.postId,
                    isEngagementAllowed: isEngagementAllowed
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: DSSpacing.xs, leading: DSSpacing.md, bottom: DSSpacing.xs, trailing: DSSpacing.md))
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    guard isEngagementAllowed else {
                        onEngagementBlocked?()
                        return
                    }
                    Task { await viewModel.doubleTapLike(post: post) }
                }
                .onLongPressGesture(minimumDuration: 0.45) {
                    guard isEngagementAllowed else {
                        onEngagementBlocked?()
                        return
                    }
                    viewModel.beginComment(on: post)
                }
                .onAppear {
                    Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.reload()
        }
    }
}

private struct FeedUnreadBadge: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "heart.text.square")
                .foregroundStyle(DSColors.textPrimary)
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textOnPrimary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(Capsule())
                .offset(x: 8, y: -6)
        }
        .accessibilityLabel("未读互动 \(count) 条")
    }
}

private struct FeedPostRow: View {
    let caption: String
    let createdAt: String
    let mediaCount: Int
    let hasVideo: Bool
    let engagement: FeedEngagementState
    let showLikeAnimation: Bool
    let isEngagementAllowed: Bool

    var body: some View {
        ZStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: hasVideo ? "video.fill" : "photo.fill")
                        .foregroundStyle(DSColors.primary)
                    Text(mediaSummary)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                    Spacer()
                    if engagement.unreadCount > 0 {
                        FeedPostUnreadDot(count: engagement.unreadCount)
                    }
                    Text(formattedDate)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                }

                Text(caption)
                    .font(DSTypography.body)
                    .foregroundStyle(DSColors.textPrimary)
                    .lineLimit(4)

                HStack(spacing: DSSpacing.md) {
                    Label("\(engagement.likeCount)", systemImage: engagement.likedByCurrentUser ? "heart.fill" : "heart")
                        .font(DSTypography.caption)
                        .foregroundStyle(engagement.likedByCurrentUser ? Color.red : DSColors.textSecondary)
                    Label("\(engagement.commentCount)", systemImage: "bubble.right")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                    Spacer()
                    if isEngagementAllowed {
                        Text("双击点赞 · 长按评论")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                    }
                }
            }
            .padding(DSSpacing.sm)
            .background(DSColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))

            if showLikeAnimation {
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var mediaSummary: String {
        if hasVideo {
            return mediaCount > 1 ? "\(mediaCount) 个媒体 · 含视频" : "视频"
        }
        return mediaCount > 1 ? "\(mediaCount) 张图片" : "图片"
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: createdAt) else {
            return createdAt
        }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        display.locale = Locale(identifier: "zh_CN")
        return display.string(from: date)
    }
}

private struct FeedPostUnreadDot: View {
    let count: Int

    var body: some View {
        Text(count > 9 ? "9+" : "\(count)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(DSColors.textOnPrimary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.red)
            .clipShape(Capsule())
    }
}
