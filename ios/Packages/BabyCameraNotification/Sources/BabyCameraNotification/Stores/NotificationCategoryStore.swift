import BabyCameraNetwork
import Foundation

/// 类目订阅开关，绑定 `GET/PATCH /v1/notifications/subscriptions`（PRD §4.12）。
@MainActor
public final class NotificationCategoryStore: ObservableObject {
    @Published public private(set) var categories: [NotificationCategory] = NotificationCategory.allDefaults
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?
    @Published public var lockedCategoryHint: String?

    public let notificationService: any NotificationServing

    public init(notificationService: any NotificationServing) {
        self.notificationService = notificationService
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            categories = try await notificationService.loadCategorySubscriptions()
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func setEnabled(_ enabled: Bool, for code: NotificationCategoryCode) async {
        guard NotificationCategory.userCanDisable(code) || enabled else {
            lockedCategoryHint = "\(NotificationCategory(code: code, enabled: true).displayName) 为关键通知，无法关闭"
            return
        }

        lockedCategoryHint = nil
        errorMessage = nil

        do {
            categories = try await notificationService.updateCategory(code, enabled: enabled)
        } catch let serviceError as NotificationServiceError {
            switch serviceError {
            case .categoryLocked(let locked):
                lockedCategoryHint = "\(NotificationCategory(code: locked, enabled: true).displayName) 为关键通知，无法关闭"
            case .notAuthenticated:
                errorMessage = "请先登录"
            }
        } catch {
            errorMessage = mapError(error)
            await load()
        }
    }

    public func isEnabled(_ code: NotificationCategoryCode) -> Bool {
        categories.first(where: { $0.code == code })?.enabled
            ?? NotificationCategory.defaultEnabled(for: code)
    }

    public func canToggle(_ code: NotificationCategoryCode) -> Bool {
        NotificationCategory.userCanDisable(code)
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }
}
