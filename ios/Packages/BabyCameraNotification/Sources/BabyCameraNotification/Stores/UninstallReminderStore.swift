import Foundation

@MainActor
public final class UninstallReminderStore: ObservableObject {
    @Published public private(set) var enabled: Bool
    @Published public var errorMessage: String?

    private let coordinator: UninstallReminderCoordinator

    public init(coordinator: UninstallReminderCoordinator) {
        self.coordinator = coordinator
        self.enabled = coordinator.currentPreferences().enabled
    }

    public func setEnabled(_ newValue: Bool) async {
        errorMessage = nil
        let previous = enabled
        enabled = newValue
        do {
            _ = try await coordinator.updatePreferences(UninstallReminderPreferences(enabled: newValue))
        } catch {
            enabled = previous
            errorMessage = "无法更新卸载提醒，请稍后重试"
        }
    }
}
