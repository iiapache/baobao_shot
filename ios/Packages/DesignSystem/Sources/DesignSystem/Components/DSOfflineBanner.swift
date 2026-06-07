import SwiftUI

/// 离线模式顶栏提示（Timeline / Feed 等本地缓存浏览场景）。
public struct DSOfflineBanner: View {
    private let message: String

    public init(message: String = "离线模式 · 显示本地缓存") {
        self.message = message
    }

    public var body: some View {
        Text(message)
            .font(DSTypography.caption)
            .foregroundStyle(DSColors.textOnPrimary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .background(DSColors.warning)
            .clipShape(Capsule())
            .padding(.top, DSSpacing.xs)
            .accessibilityIdentifier("offlineBanner")
    }
}
