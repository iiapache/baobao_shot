import BabyCameraNetwork
import DesignSystem
import SwiftUI

/// 消息中心列表；进入后标记已读并清除红点（design-ios §10.3）。
public struct NotificationCenterView: View {
    @ObservedObject private var viewModel: NotificationCenterViewModel

    public init(viewModel: NotificationCenterViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                DSLoadingView(message: "加载消息…")
            } else if viewModel.items.isEmpty, let errorMessage = viewModel.errorMessage {
                DSEmptyState(
                    systemImage: "bell.slash",
                    title: "加载失败",
                    message: errorMessage,
                    actionTitle: "重试"
                ) {
                    Task { await viewModel.reload() }
                }
            } else if viewModel.items.isEmpty {
                DSEmptyState(
                    systemImage: "bell",
                    title: "暂无消息",
                    message: "家人动态、AI 完成与积分通知会显示在这里"
                )
            } else {
                listContent
            }
        }
        .navigationTitle("消息中心")
        .task {
            await viewModel.onAppear()
        }
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.items) { item in
                NotificationRow(
                    title: viewModel.displayTitle(for: item),
                    message: viewModel.displayBody(for: item),
                    category: item.category,
                    createdAt: item.createdAt,
                    isUnread: item.isUnread
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .onAppear {
                    Task { await viewModel.loadMoreIfNeeded(currentItem: item) }
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

private struct NotificationRow: View {
    let title: String
    let message: String
    let category: NotificationCategoryCode
    let createdAt: String
    let isUnread: Bool

    private var categoryModel: NotificationCategory {
        NotificationCategory(code: category, enabled: true)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: categoryModel.systemImage)
                .font(DSTypography.body)
                .foregroundStyle(DSColors.primary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(DSTypography.listTitle)
                        .foregroundStyle(DSColors.textPrimary)
                    Spacer(minLength: DSSpacing.xs)
                    if isUnread {
                        Circle()
                            .fill(DSColors.error)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel("未读")
                    }
                }

                if !message.isEmpty {
                    Text(message)
                        .font(DSTypography.listSubtitle)
                        .foregroundStyle(DSColors.textSecondary)
                        .lineLimit(2)
                }

                Text(formattedDate)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textTertiary)
            }
        }
        .padding(.horizontal, DSSpacing.listRowHorizontalPadding)
        .padding(.vertical, DSSpacing.sm)
        .background(DSColors.surface)
        .accessibilityElement(children: .combine)
    }

    private var formattedDate: String {
        guard let date = ISO8601DateFormatter().date(from: createdAt) else {
            return createdAt
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        NotificationCenterView(
            viewModel: NotificationCenterViewModel(
                notificationService: PreviewNotificationService(),
                badgeStore: UnreadBadgeStore(notificationService: PreviewNotificationService())
            )
        )
    }
}

@MainActor
private final class PreviewNotificationService: NotificationServing {
    var unreadCount: Int { 1 }

    func refreshUnreadCount() async throws {}
    func listNotifications(cursor: String?) async throws -> NotificationListData {
        NotificationListData(
            items: [
                NotificationItem(
                    id: "ntf_preview",
                    category: .familyActivity,
                    payload: NotificationPayload(title: "外婆点赞了照片", body: "豆豆的第 100 天"),
                    createdAt: ISO8601DateFormatter().string(from: Date())
                ),
            ],
            unreadCount: 1
        )
    }
    func markAllRead() async throws -> MarkNotificationsReadData {
        MarkNotificationsReadData(markedCount: 1, unreadCount: 0)
    }
    func loadCategorySubscriptions() async throws -> [NotificationCategory] {
        NotificationCategory.allDefaults
    }
    func updateCategory(_ category: NotificationCategoryCode, enabled: Bool) async throws -> [NotificationCategory] {
        NotificationCategory.allDefaults
    }
}
