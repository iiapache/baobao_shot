import CoreGraphics

/// 4pt 网格间距系统。
public enum DSSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48

    // MARK: - Component

    public static let buttonHorizontalPadding: CGFloat = md
    public static let buttonVerticalPaddingLarge: CGFloat = sm + 2 // 14
    public static let buttonVerticalPaddingMedium: CGFloat = xs + 2 // 10
    public static let buttonVerticalPaddingSmall: CGFloat = xxs + 2 // 6

    public static let cardPadding: CGFloat = md
    public static let cardCornerRadius: CGFloat = sm
    public static let listRowMinHeight: CGFloat = 44
    public static let listRowHorizontalPadding: CGFloat = md
    public static let emptyStateVerticalPadding: CGFloat = xl
}
