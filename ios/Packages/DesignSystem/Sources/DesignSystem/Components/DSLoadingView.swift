import SwiftUI

/// 全屏或内联 Loading 指示器。
public struct DSLoadingView: View {
    public enum Style {
        case inline
        case overlay
        case fullScreen
    }

    private let message: String?
    private let style: Style

    public init(
        message: String? = nil,
        style: Style = .inline
    ) {
        self.message = message
        self.style = style
    }

    public var body: some View {
        Group {
            switch style {
            case .inline:
                inlineContent
            case .overlay:
                overlayContent
            case .fullScreen:
                fullScreenContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "加载中")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var inlineContent: some View {
        HStack(spacing: DSSpacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(DSColors.primary)
            if let message {
                Text(message)
                    .font(DSTypography.loadingMessage)
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
        .padding(DSSpacing.md)
    }

    private var overlayContent: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            loadingCard
        }
    }

    private var fullScreenContent: some View {
        ZStack {
            DSColors.background
                .ignoresSafeArea()

            loadingCard
        }
    }

    private var loadingCard: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
                .tint(DSColors.primary)

            if let message {
                Text(message)
                    .font(DSTypography.loadingMessage)
                    .foregroundStyle(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DSSpacing.lg)
        .background(DSColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

#Preview("Inline") {
    DSLoadingView(message: "同步中…", style: .inline)
}

#Preview("Full Screen") {
    DSLoadingView(message: "正在加载照片", style: .fullScreen)
}
