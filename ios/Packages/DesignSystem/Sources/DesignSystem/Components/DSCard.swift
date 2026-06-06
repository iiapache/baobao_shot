import SwiftUI

/// 卡片容器 — 可选标题、副标题与自定义内容。
public struct DSCard<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    private let content: Content

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    if let title {
                        Text(title)
                            .font(DSTypography.headline)
                            .foregroundStyle(DSColors.textPrimary)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(DSTypography.subheadline)
                            .foregroundStyle(DSColors.textSecondary)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.cardPadding)
        .background(DSColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius)
                .stroke(DSColors.separator, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    DSCard(title: "今日照片", subtitle: "3 张新照片") {
        RoundedRectangle(cornerRadius: DSSpacing.xs)
            .fill(DSColors.primaryMuted)
            .frame(height: 120)
            .overlay {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(DSColors.primary)
            }
    }
    .padding()
    .background(DSColors.background)
}
