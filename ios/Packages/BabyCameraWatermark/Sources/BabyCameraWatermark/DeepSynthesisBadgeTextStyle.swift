import UIKit

enum DeepSynthesisBadgeTextStyle {
    static func uiFont(size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .semibold)
    }

    static func attributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: uiFont(size: fontSize),
            .foregroundColor: UIColor.white.withAlphaComponent(DeepSynthesisBadgeLayout.textOpacity),
        ]
    }
}
