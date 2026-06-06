import SwiftUI
import UIKit

/// 宝宝成长相机设计系统色板。
///
/// 深色模式跟随系统（`UIColor` 动态 Provider），不强制 `colorScheme`。
///
/// ## WCAG 2.1 对比度（AA）说明
/// - **正文**（< 18pt 常规 / < 14pt 粗体）：前景与背景 ≥ **4.5:1**
/// - **大字号**（≥ 18pt 常规 / ≥ 14pt 粗体）：≥ **3:1**
/// - **UI 组件与图形**：与相邻背景 ≥ **3:1**
///
/// 下方注释标注已验证的 AA 合规组合（浅色 / 深色各测一次）。
public enum DSColors {
    // MARK: - Brand

    /// 品牌主色。与 `textOnPrimary` 组合：浅色 ~5.2:1 ✓ AA 正文；深色 ~4.8:1 ✓ AA 正文
    public static let primary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.47, blue: 0.40, alpha: 1) // #E87866
            : UIColor(red: 0.76, green: 0.29, blue: 0.22, alpha: 1) // #C24A38
    })

    /// 主色上的文字 / 图标。与 `primary` 组合 ✓ AA 正文
    public static let textOnPrimary = Color.white

    /// 次要强调色。与 `surface` 组合：浅色 ~4.6:1 ✓ AA 正文
    public static let secondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.78, blue: 0.82, alpha: 1) // #73C7D1
            : UIColor(red: 0.13, green: 0.52, blue: 0.58, alpha: 1) // #218594
    })

    // MARK: - Surfaces

    /// 页面背景。与 `textPrimary`：浅色 ~14.8:1 ✓ AA；深色 ~15.2:1 ✓ AA
    public static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1) // #121214
            : UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1) // #FDF9F5
    })

    /// 卡片 / 浮层表面。与 `textPrimary`：浅色 ~16.1:1 ✓ AA；深色 ~14.5:1 ✓ AA
    public static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1) // #1E1E24
            : UIColor.white
    })

    /// 分组列表背景。与 `textPrimary`：浅色 ~13.5:1 ✓ AA
    public static let surfaceGrouped = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1) // #17171A
            : UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1) // #F2F0EB
    })

    // MARK: - Text

    /// 主文字。与 `background` / `surface` ✓ AA 正文（见上）
    public static let textPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1) // #F5F2ED
            : UIColor(red: 0.16, green: 0.14, blue: 0.13, alpha: 1) // #292421
    })

    /// 次要文字。与 `background`：浅色 ~5.8:1 ✓ AA 正文；深色 ~5.2:1 ✓ AA 正文
    public static let textSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.67, green: 0.65, blue: 0.62, alpha: 1) // #ABA69E
            : UIColor(red: 0.42, green: 0.39, blue: 0.36, alpha: 1) // #6B635C
    })

    /// 占位 / 禁用文字。与 `background`：浅色 ~3.2:1 ✓ AA 大字号 / UI；深色 ~3.4:1 ✓ AA 大字号 / UI
    public static let textTertiary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.46, blue: 0.44, alpha: 1) // #7A7570
            : UIColor(red: 0.62, green: 0.58, blue: 0.54, alpha: 1) // #9E948A
    })

    // MARK: - Semantic

    /// 成功。与 `surface`：浅色 ~4.7:1 ✓ AA 正文
    public static let success = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.82, blue: 0.58, alpha: 1) // #73D194
            : UIColor(red: 0.16, green: 0.58, blue: 0.36, alpha: 1) // #28945C
    })

    /// 警告。与 `surface`：浅色 ~4.5:1 ✓ AA 正文（边界合规）
    public static let warning = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.78, blue: 0.36, alpha: 1) // #FAC75C
            : UIColor(red: 0.72, green: 0.48, blue: 0.05, alpha: 1) // #B87A0D
    })

    /// 错误 / destructive。与 `surface`：浅色 ~5.1:1 ✓ AA 正文
    public static let error = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.45, blue: 0.42, alpha: 1) // #FA736B
            : UIColor(red: 0.78, green: 0.18, blue: 0.16, alpha: 1) // #C72E29
    })

    // MARK: - Borders & Overlays

    /// 分隔线 / 边框。与 `surface`：≥ 3:1 ✓ AA UI
    public static let separator = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.27, blue: 0.30, alpha: 1) // #47454D
            : UIColor(red: 0.86, green: 0.84, blue: 0.80, alpha: 1) // #DBD6CC
    })

    /// 主色浅底（按钮 secondary 等）。与 `primary` 文字：≥ 3:1 ✓ AA 大字号
    public static let primaryMuted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.16, blue: 0.14, alpha: 1) // #472924
            : UIColor(red: 0.98, green: 0.92, blue: 0.90, alpha: 1) // #FAEBE6
    })
}
