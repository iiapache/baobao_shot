import SwiftUI

/// 设计系统按钮 — 支持多种样式、尺寸与 Loading 态。
public struct DSButton: View {
    public enum Style {
        case primary
        case secondary
        case destructive
        case ghost
    }

    public enum Size {
        case large
        case medium
        case small

        var verticalPadding: CGFloat {
            switch self {
            case .large: DSSpacing.buttonVerticalPaddingLarge
            case .medium: DSSpacing.buttonVerticalPaddingMedium
            case .small: DSSpacing.buttonVerticalPaddingSmall
            }
        }

        var font: Font {
            switch self {
            case .large: DSTypography.buttonLarge
            case .medium: DSTypography.buttonMedium
            case .small: DSTypography.buttonSmall
            }
        }

        var minHeight: CGFloat {
            switch self {
            case .large: 50
            case .medium: 44
            case .small: 36
            }
        }
    }

    private let title: String
    private let style: Style
    private let size: Size
    private let isLoading: Bool
    private let isDisabled: Bool
    private let systemImage: String?
    private let action: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        size: Size = .medium,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foregroundColor)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(size.font)
                }
                Text(title)
                    .font(size.font)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: size.minHeight)
            .padding(.horizontal, DSSpacing.buttonHorizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .overlay {
                if style == .ghost {
                    RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius)
                        .stroke(borderColor, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isLoading ? [.isButton, .updatesFrequently] : .isButton)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: DSColors.textOnPrimary
        case .secondary: DSColors.primary
        case .destructive: DSColors.textOnPrimary
        case .ghost: DSColors.primary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: DSColors.primary
        case .secondary: DSColors.primaryMuted
        case .destructive: DSColors.error
        case .ghost: .clear
        }
    }

    private var borderColor: Color {
        DSColors.separator
    }
}

#Preview {
    VStack(spacing: DSSpacing.sm) {
        DSButton("主要操作", style: .primary, systemImage: "camera.fill") {}
        DSButton("次要操作", style: .secondary) {}
        DSButton("删除", style: .destructive) {}
        DSButton("加载中", style: .primary, isLoading: true) {}
    }
    .padding()
}
