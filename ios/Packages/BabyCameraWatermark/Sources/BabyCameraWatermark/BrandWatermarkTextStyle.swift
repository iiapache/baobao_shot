import UIKit

enum BrandWatermarkTextStyle {
    static func uiFont(size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .medium)
    }

    static func attributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        shadow.shadowBlurRadius = 2

        return [
            .font: uiFont(size: fontSize),
            .foregroundColor: UIColor.white.withAlphaComponent(BrandWatermarkLayout.textOpacity),
            .shadow: shadow,
        ]
    }
}
