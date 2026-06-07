import Foundation

/// 转让 / 接管流程 UI 状态机
public enum FamilyAdminFlowState: Equatable, Sendable {
    case idle
    case confirming
    case submitting
    case success
    case error(String)

    public var isBusy: Bool {
        if case .submitting = self { return true }
        return false
    }

    public var errorMessage: String? {
        if case let .error(message) = self { return message }
        return nil
    }
}
