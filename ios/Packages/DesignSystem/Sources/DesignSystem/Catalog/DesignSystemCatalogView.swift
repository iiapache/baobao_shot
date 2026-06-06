import SwiftUI

/// Storybook 风格设计系统演示页 — 供开发 / QA 验收颜色、排版、间距与组件。
public struct DesignSystemCatalogView: View {
    @State private var toggleOn = true
    @State private var selectedSection: CatalogSection = .colors

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("章节", selection: $selectedSection) {
                        ForEach(CatalogSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.menu)
                }

                sectionContent
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DSColors.background)
            .navigationTitle("Design System")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .colors:
            colorsSection
        case .typography:
            typographySection
        case .spacing:
            spacingSection
        case .buttons:
            buttonsSection
        case .cards:
            cardsSection
        case .lists:
            listsSection
        case .emptyStates:
            emptyStatesSection
        case .loading:
            loadingSection
        }
    }

    // MARK: - Colors

    private var colorsSection: some View {
        Group {
            Section("品牌") {
                colorSwatch("Primary", color: DSColors.primary, note: "textOnPrimary ✓ AA 正文")
                colorSwatch("Secondary", color: DSColors.secondary, note: "surface 上 ✓ AA 正文")
                colorSwatch("Primary Muted", color: DSColors.primaryMuted, note: "secondary 按钮底")
            }
            Section("表面") {
                colorSwatch("Background", color: DSColors.background, note: "textPrimary ✓ AA 正文 ~15:1")
                colorSwatch("Surface", color: DSColors.surface, note: "卡片 / 浮层")
                colorSwatch("Surface Grouped", color: DSColors.surfaceGrouped, note: "列表分组底")
            }
            Section("文字") {
                colorSwatch("Text Primary", color: DSColors.textPrimary, note: "background ✓ AA 正文")
                colorSwatch("Text Secondary", color: DSColors.textSecondary, note: "background ✓ AA 正文 ~5.8:1")
                colorSwatch("Text Tertiary", color: DSColors.textTertiary, note: "✓ AA 大字号 / UI")
            }
            Section("语义") {
                colorSwatch("Success", color: DSColors.success, note: "surface ✓ AA 正文")
                colorSwatch("Warning", color: DSColors.warning, note: "surface ✓ AA 正文")
                colorSwatch("Error", color: DSColors.error, note: "destructive 按钮")
            }
            Section("对比度说明") {
                Text("所有前景/背景组合均按 WCAG 2.1 AA 标注于 `DSColors.swift`。正文 ≥ 4.5:1，大字号 / UI ≥ 3:1。深色模式跟随系统，未强制 colorScheme。")
                    .font(DSTypography.footnote)
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
    }

    private func colorSwatch(_ name: String, color: Color, note: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            RoundedRectangle(cornerRadius: DSSpacing.xxs)
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: DSSpacing.xxs)
                        .stroke(DSColors.separator, lineWidth: 0.5)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(DSTypography.listTitle)
                    .foregroundStyle(DSColors.textPrimary)
                Text(note)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }

    // MARK: - Typography

    private var typographySection: some View {
        Group {
            Section("Dynamic Type 预览") {
                typographyRow("Large Title", font: DSTypography.largeTitle)
                typographyRow("Title", font: DSTypography.title)
                typographyRow("Title 2", font: DSTypography.title2)
                typographyRow("Title 3", font: DSTypography.title3)
                typographyRow("Headline", font: DSTypography.headline)
                typographyRow("Body", font: DSTypography.body)
                typographyRow("Callout", font: DSTypography.callout)
                typographyRow("Subheadline", font: DSTypography.subheadline)
                typographyRow("Footnote", font: DSTypography.footnote)
                typographyRow("Caption", font: DSTypography.caption)
            }
            Section("说明") {
                Text("全部使用系统文本样式，请在「设置 → 辅助功能 → 显示与文字大小」调整字号验证布局。")
                    .font(DSTypography.footnote)
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
    }

    private func typographyRow(_ name: String, font: Font) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Text(name)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textTertiary)
            Text("宝宝成长相机 BabyCamera")
                .font(font)
                .foregroundStyle(DSColors.textPrimary)
        }
        .padding(.vertical, DSSpacing.xxs)
    }

    // MARK: - Spacing

    private var spacingSection: some View {
        Group {
            Section("间距刻度（4pt 网格）") {
                spacingRow("xxs", value: DSSpacing.xxs)
                spacingRow("xs", value: DSSpacing.xs)
                spacingRow("sm", value: DSSpacing.sm)
                spacingRow("md", value: DSSpacing.md)
                spacingRow("lg", value: DSSpacing.lg)
                spacingRow("xl", value: DSSpacing.xl)
                spacingRow("xxl", value: DSSpacing.xxl)
            }
        }
    }

    private func spacingRow(_ name: String, value: CGFloat) -> some View {
        HStack {
            Text(name)
                .font(DSTypography.listTitle)
                .frame(width: 40, alignment: .leading)
            Text("\(Int(value))pt")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
                .frame(width: 36, alignment: .trailing)
            RoundedRectangle(cornerRadius: 2)
                .fill(DSColors.primary)
                .frame(width: value * 4, height: 12)
        }
    }

    // MARK: - Components

    private var buttonsSection: some View {
        Section("DSButton") {
            VStack(spacing: DSSpacing.sm) {
                DSButton("Primary", style: .primary, systemImage: "camera.fill") {}
                DSButton("Secondary", style: .secondary) {}
                DSButton("Destructive", style: .destructive, systemImage: "trash") {}
                DSButton("Ghost", style: .ghost) {}
                DSButton("Loading", style: .primary, isLoading: true) {}
                DSButton("Disabled", style: .primary, isDisabled: true) {}
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(DSSpacing.md)
        }
    }

    private var cardsSection: some View {
        Section("DSCard") {
            DSCard(title: "今日精选", subtitle: "2026 年 6 月 6 日") {
                HStack(spacing: DSSpacing.xs) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: DSSpacing.xxs)
                            .fill(DSColors.primaryMuted)
                            .frame(height: 72)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs)
        }
    }

    private var listsSection: some View {
        Section("DSListRow") {
            VStack(spacing: 0) {
                DSListRow(
                    icon: "person.2.fill",
                    title: "家庭组",
                    subtitle: "3 位成员",
                    action: {}
                )
                DSListRow(
                    icon: "bell.fill",
                    iconColor: DSColors.secondary,
                    title: "推送通知",
                    showsDivider: true
                ) {
                    Toggle("", isOn: $toggleOn)
                        .labelsHidden()
                }
                DSListRow(
                    icon: "icloud.fill",
                    title: "iCloud 备份",
                    subtitle: "上次同步：今天 10:30",
                    showsDivider: false,
                    action: {}
                )
            }
            .background(DSColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(.horizontal, DSSpacing.md)
        }
    }

    private var emptyStatesSection: some View {
        Section("DSEmptyState") {
            DSEmptyState(
                systemImage: "photo.on.rectangle.angled",
                title: "还没有照片",
                message: "拍第一张宝宝照片，开始记录成长瞬间。",
                actionTitle: "打开相机"
            ) {}
            .frame(height: 280)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var loadingSection: some View {
        Group {
            Section("Inline") {
                DSLoadingView(message: "同步中…", style: .inline)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(DSColors.surface)
            }
            Section("Overlay 预览") {
                ZStack {
                    DSColors.surfaceGrouped
                    DSLoadingView(message: "正在上传", style: .overlay)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.horizontal, DSSpacing.md)
            }
        }
    }
}

// MARK: - Catalog Section

private enum CatalogSection: String, CaseIterable, Identifiable {
    case colors
    case typography
    case spacing
    case buttons
    case cards
    case lists
    case emptyStates
    case loading

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colors: "颜色 Colors"
        case .typography: "排版 Typography"
        case .spacing: "间距 Spacing"
        case .buttons: "按钮 Button"
        case .cards: "卡片 Card"
        case .lists: "列表 List"
        case .emptyStates: "空态 Empty"
        case .loading: "Loading"
        }
    }
}

#Preview {
    DesignSystemCatalogView()
}
