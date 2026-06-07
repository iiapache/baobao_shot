import SwiftUI

/// 错误态视图 — 网络异常、业务失败等场景的统一展示。
public struct DSErrorView: View {
    public enum Style {
        /// 占满可用区域，与 `DSEmptyState` 布局一致。
        case fullScreen
        /// 紧凑横幅，适合列表顶部或表单内嵌提示。
        case banner
    }

    public enum Kind {
        case network
        case generic
        case insufficientCredit
        case auditRejected

        var defaultSystemImage: String {
            switch self {
            case .network:
                return "wifi.exclamationmark"
            case .generic:
                return "exclamationmark.triangle.fill"
            case .insufficientCredit:
                return "creditcard.trianglebadge.exclamationmark"
            case .auditRejected:
                return "hand.raised.fill"
            }
        }

        var defaultTitle: String {
            switch self {
            case .network:
                return "网络连接异常"
            case .generic:
                return "出了点问题"
            case .insufficientCredit:
                return "积分不足"
            case .auditRejected:
                return "内容未通过审核"
            }
        }

        var defaultMessage: String {
            switch self {
            case .network:
                return "请检查网络后重试"
            case .generic:
                return "操作失败，请稍后重试"
            case .insufficientCredit:
                return "当前积分不足以完成本次生成，可签到领取或充值后再试"
            case .auditRejected:
                return "该内容不符合社区规范，积分已退还"
            }
        }

        var iconColor: Color {
            switch self {
            case .network, .generic:
                return DSColors.warning
            case .insufficientCredit, .auditRejected:
                return DSColors.error
            }
        }
    }

    private let kind: Kind
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let secondaryActionTitle: String?
    private let style: Style
    private let action: (() -> Void)?
    private let secondaryAction: (() -> Void)?

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 56

    public init(
        kind: Kind = .generic,
        systemImage: String? = nil,
        title: String? = nil,
        message: String? = nil,
        actionTitle: String? = "重试",
        secondaryActionTitle: String? = nil,
        style: Style = .fullScreen,
        action: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.systemImage = systemImage ?? kind.defaultSystemImage
        self.title = title ?? kind.defaultTitle
        self.message = message ?? kind.defaultMessage
        self.actionTitle = actionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.style = style
        self.action = action
        self.secondaryAction = secondaryAction
    }

    public var body: some View {
        Group {
            switch style {
            case .fullScreen:
                fullScreenContent
            case .banner:
                bannerContent
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var fullScreenContent: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(kind.iconColor)
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

            actionButtons
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.emptyStateVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bannerContent: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(kind.iconColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .font(DSTypography.subheadline.weight(.semibold))
                    .foregroundStyle(DSColors.textPrimary)

                Text(message)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if actionTitle != nil || secondaryActionTitle != nil {
                    HStack(spacing: DSSpacing.sm) {
                        if let actionTitle, let action {
                            Button(actionTitle, action: action)
                                .font(DSTypography.caption.weight(.semibold))
                                .foregroundStyle(DSColors.primary)
                        }
                        if let secondaryActionTitle, let secondaryAction {
                            Button(secondaryActionTitle, action: secondaryAction)
                                .font(DSTypography.caption.weight(.semibold))
                                .foregroundStyle(DSColors.secondary)
                        }
                    }
                    .padding(.top, DSSpacing.xxs)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(DSSpacing.sm)
        .background(kind.iconColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if actionTitle != nil || secondaryActionTitle != nil {
            VStack(spacing: DSSpacing.sm) {
                if let actionTitle, let action {
                    DSButton(actionTitle, style: .primary, size: .medium, action: action)
                        .frame(maxWidth: 240)
                }
                if let secondaryActionTitle, let secondaryAction {
                    DSButton(secondaryActionTitle, style: .secondary, size: .medium, action: secondaryAction)
                        .frame(maxWidth: 240)
                }
            }
            .padding(.top, DSSpacing.xs)
        }
    }
}

public enum DSUserFacingError {
    /// 将系统 / 网络错误映射为对用户友好的说明。
    public static func message(from error: Error, fallback: String = "操作失败，请稍后重试") -> String {
        if let urlError = error as? URLError {
            return networkMessage(for: urlError)
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        let description = error.localizedDescription
        if !description.isEmpty, description != "The operation couldn't be completed." {
            return description
        }
        return fallback
    }

    public static func kind(for error: Error) -> DSErrorView.Kind {
        if error is URLError {
            return .network
        }
        return .generic
    }

    public static func networkMessage(for urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "当前无网络连接，请检查网络设置"
        case .timedOut:
            return "连接超时，请稍后重试"
        case .cannotFindHost, .cannotConnectToHost:
            return "无法连接服务器，请稍后重试"
        default:
            return "网络异常，请稍后重试"
        }
    }
}

#Preview("Full Screen Network") {
    DSErrorView(kind: .network, action: {})
        .background(DSColors.background)
}

#Preview("Banner Insufficient Credit") {
    DSErrorView(
        kind: .insufficientCredit,
        actionTitle: "去充值",
        secondaryActionTitle: "去签到",
        style: .banner,
        action: {},
        secondaryAction: {}
    )
    .padding()
    .background(DSColors.background)
}
