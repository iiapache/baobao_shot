import SwiftUI

/// 空态视图 — 图标、标题、说明与可选操作按钮。
public struct DSEmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 56

    public init(
        systemImage: String = "photo.on.rectangle.angled",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                // 装饰性图标，允许固定比例缩放而非文本样式
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(DSColors.primary)
                .accessibilityHidden(true)

            VStack(spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSTypography.emptyTitle)
                    .foregroundStyle(DSColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(DSTypography.emptyMessage)
                    .foregroundStyle(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                DSButton(actionTitle, style: .primary, size: .medium, action: action)
                    .frame(maxWidth: 240)
                    .padding(.top, DSSpacing.xs)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.emptyStateVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DSEmptyState(
        systemImage: "camera.fill",
        title: "还没有照片",
        message: "拍第一张宝宝照片，开始记录成长瞬间吧。",
        actionTitle: "打开相机"
    ) {}
    .background(DSColors.background)
}
