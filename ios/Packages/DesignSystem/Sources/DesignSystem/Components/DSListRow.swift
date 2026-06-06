import SwiftUI

/// 列表行 — 图标、标题、副标题、尾部控件或 chevron。
public struct DSListRow<Trailing: View>: View {
    private let icon: String?
    private let iconColor: Color
    private let title: String
    private let subtitle: String?
    private let showsDivider: Bool
    private let trailing: Trailing
    private let action: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 28

    public init(
        icon: String? = nil,
        iconColor: Color = DSColors.primary,
        title: String,
        subtitle: String? = nil,
        showsDivider: Bool = true,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.showsDivider = showsDivider
        self.action = action
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(spacing: 0) {
            rowContent
                .contentShape(Rectangle())
                .onTapGesture {
                    action?()
                }

            if showsDivider {
                Divider()
                    .overlay(DSColors.separator)
                    .padding(.leading, dividerLeadingInset)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(action != nil ? .isButton : [])
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: DSSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(DSTypography.body)
                    .foregroundStyle(iconColor)
                    .frame(width: iconSize, height: iconSize)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .font(DSTypography.listTitle)
                    .foregroundStyle(DSColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(DSTypography.listSubtitle)
                        .foregroundStyle(DSColors.textSecondary)
                }
            }

            Spacer(minLength: DSSpacing.xs)

            trailing
        }
        .padding(.horizontal, DSSpacing.listRowHorizontalPadding)
        .frame(minHeight: DSSpacing.listRowMinHeight)
    }

    private var dividerLeadingInset: CGFloat {
        if icon != nil {
            DSSpacing.listRowHorizontalPadding + iconSize + DSSpacing.sm
        } else {
            DSSpacing.listRowHorizontalPadding
        }
    }

    private var accessibilityLabelText: String {
        if let subtitle {
            "\(title)，\(subtitle)"
        } else {
            title
        }
    }
}

public extension DSListRow where Trailing == EmptyView {
    init(
        icon: String? = nil,
        iconColor: Color = DSColors.primary,
        title: String,
        subtitle: String? = nil,
        showsDivider: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.init(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            showsDivider: showsDivider,
            action: action
        ) {
            EmptyView()
        }
    }
}

public extension DSListRow where Trailing == Image {
    init(
        icon: String? = nil,
        iconColor: Color = DSColors.primary,
        title: String,
        subtitle: String? = nil,
        showsChevron: Bool = true,
        showsDivider: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.init(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            showsDivider: showsDivider,
            action: action
        ) {
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(DSTypography.caption.weight(.semibold))
                    .foregroundStyle(DSColors.textTertiary)
            } else {
                Image(systemName: "")
                    .hidden()
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        DSListRow(
            icon: "person.2.fill",
            title: "家庭组",
            subtitle: "3 位成员",
            showsDivider: true
        ) {}
        DSListRow(
            icon: "bell.fill",
            title: "通知设置",
            showsDivider: false
        ) {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
    }
    .background(DSColors.surface)
}
