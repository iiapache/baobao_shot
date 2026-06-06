import SwiftUI

/// 宝宝成长相机 DesignSystem 模块入口。
public enum DesignSystem {
    public static let version = "1.0.0"

    /// Storybook 演示页 — 开发 / QA 验收用。
    public static var catalog: some View {
        DesignSystemCatalogView()
    }
}

// 向后兼容占位（T0.13）
public enum DesignSystemPlaceholder {
    public static let version = DesignSystem.version
}
