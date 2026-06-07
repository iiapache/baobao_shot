import BabyCameraNetwork
import DesignSystem
import SwiftUI

/// 通知类目开关列表（PRD §4.12）。
public struct NotificationCategorySettingsView: View {
    @ObservedObject private var store: NotificationCategoryStore

    public init(store: NotificationCategoryStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isLoading && store.categories.isEmpty {
                DSLoadingView(message: "加载通知设置…")
            } else {
                settingsContent
            }
        }
        .navigationTitle("通知设置")
        .task {
            await store.load()
        }
        .alert(
            "无法关闭",
            isPresented: Binding(
                get: { store.lockedCategoryHint != nil },
                set: { if !$0 { store.lockedCategoryHint = nil } }
            )
        ) {
            Button("知道了", role: .cancel) {
                store.lockedCategoryHint = nil
            }
        } message: {
            Text(store.lockedCategoryHint ?? "")
        }
    }

    private var settingsContent: some View {
        VStack(spacing: 0) {
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DSSpacing.listRowHorizontalPadding)
                    .padding(.vertical, DSSpacing.xs)
            }

            ForEach(Array(store.categories.enumerated()), id: \.element.id) { index, category in
                DSListRow(
                    icon: category.systemImage,
                    title: category.displayName,
                    subtitle: category.subtitle,
                    showsDivider: index < store.categories.count - 1
                ) {
                    if store.canToggle(category.code) {
                        Toggle("", isOn: binding(for: category.code))
                            .labelsHidden()
                    } else {
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                            .disabled(true)
                    }
                }
            }
        }
        .background(DSColors.surface)
    }

    private func binding(for code: NotificationCategoryCode) -> Binding<Bool> {
        Binding(
            get: { store.isEnabled(code) },
            set: { newValue in
                Task { await store.setEnabled(newValue, for: code) }
            }
        )
    }
}

#Preview {
    NavigationStack {
        NotificationCategorySettingsView(
            store: NotificationCategoryStore(notificationService: PreviewCategoryService())
        )
    }
}

@MainActor
private final class PreviewCategoryService: NotificationServing {
    var unreadCount: Int { 0 }
    func refreshUnreadCount() async throws {}
    func listNotifications(cursor: String?) async throws -> NotificationListData {
        NotificationListData(items: [], unreadCount: 0)
    }
    func markAllRead() async throws -> MarkNotificationsReadData {
        MarkNotificationsReadData(markedCount: 0, unreadCount: 0)
    }
    func loadCategorySubscriptions() async throws -> [NotificationCategory] {
        NotificationCategory.allDefaults
    }
    func updateCategory(_ category: NotificationCategoryCode, enabled: Bool) async throws -> [NotificationCategory] {
        NotificationCategory.allDefaults
    }
}
