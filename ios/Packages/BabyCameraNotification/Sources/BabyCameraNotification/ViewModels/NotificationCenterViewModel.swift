import BabyCameraNetwork
import Foundation

@MainActor
public final class NotificationCenterViewModel: ObservableObject {
    @Published public private(set) var items: [NotificationItem] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public var errorMessage: String?

    public let notificationService: any NotificationServing
    public let badgeStore: UnreadBadgeStore

    private var nextCursor: String?
    private var hasMarkedReadOnAppear = false

    public init(
        notificationService: any NotificationServing,
        badgeStore: UnreadBadgeStore
    ) {
        self.notificationService = notificationService
        self.badgeStore = badgeStore
    }

    public var hasUnread: Bool {
        items.contains(where: \.isUnread)
    }

    public func onAppear() async {
        await reload()
        if !hasMarkedReadOnAppear {
            await markAllReadAndClearBadge()
            hasMarkedReadOnAppear = true
        }
    }

    public func reload() async {
        isLoading = true
        errorMessage = nil
        nextCursor = nil
        defer { isLoading = false }

        do {
            let page = try await notificationService.listNotifications(cursor: nil)
            items = page.items
            nextCursor = page.nextCursor
            badgeStore.syncFromServerCount(page.unreadCount)
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func loadMoreIfNeeded(currentItem: NotificationItem) async {
        guard let nextCursor, !nextCursor.isEmpty, !isLoadingMore else { return }
        guard items.last?.id == currentItem.id else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await notificationService.listNotifications(cursor: nextCursor)
            items.append(contentsOf: page.items)
            self.nextCursor = page.nextCursor
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func markAllReadAndClearBadge() async {
        do {
            let result = try await notificationService.markAllRead()
            items = items.map { item in
                NotificationItem(
                    id: item.id,
                    category: item.category,
                    payload: item.payload,
                    readAt: item.readAt ?? ISO8601DateFormatter().string(from: Date()),
                    createdAt: item.createdAt
                )
            }
            badgeStore.clear()
            badgeStore.syncFromServerCount(result.unreadCount)
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func displayTitle(for item: NotificationItem) -> String {
        if let title = item.payload.title, !title.isEmpty {
            return title
        }
        return NotificationCategory(code: item.category, enabled: true).displayName
    }

    public func displayBody(for item: NotificationItem) -> String {
        item.payload.body ?? ""
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }
}
