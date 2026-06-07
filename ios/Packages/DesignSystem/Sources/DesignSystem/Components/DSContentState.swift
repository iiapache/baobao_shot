import SwiftUI

/// 列表 / 页面级 Loading、空态、错误态的统一分支辅助。
public enum DSContentState {
    case loading(message: String)
    case empty(DSEmptyState)
    case error(DSErrorView)
    case content
}

public extension View {
    /// 根据加载 / 错误 / 空数据条件渲染 Design System 标准态。
    @ViewBuilder
    func dsContentState(
        isLoading: Bool,
        isEmpty: Bool,
        errorMessage: String?,
        loadingMessage: String,
        empty: () -> DSEmptyState,
        error: (_ message: String) -> DSErrorView,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if isLoading, isEmpty {
            DSLoadingView(message: loadingMessage, style: .fullScreen)
        } else if isEmpty, let errorMessage {
            error(errorMessage)
        } else if isEmpty {
            empty()
        } else {
            content()
        }
    }
}
