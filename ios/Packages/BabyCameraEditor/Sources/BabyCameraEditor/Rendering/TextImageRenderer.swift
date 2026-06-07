import CoreImage
import Foundation

#if canImport(UIKit)
import UIKit

enum TextImageRenderer {
    static func render(
        text: String,
        postScriptName: String,
        fontSize: CGFloat,
        colorHex: String,
        canvasExtent: CGRect
    ) -> CIImage? {
        guard !text.isEmpty else { return nil }

        let font = UIFont(name: postScriptName, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: .regular)
        let color = uiColor(from: colorHex)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let size = CGSize(
            width: max(ceil(textSize.width) + 8, 1),
            height: max(ceil(textSize.height) + 4, 1)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let uiImage = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            attributed.draw(at: CGPoint(x: 4, y: 2))
        }

        guard let cgImage = uiImage.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }

    private static func uiColor(from hex: String) -> UIColor {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }
        guard sanitized.count == 6 || sanitized.count == 8,
              let value = UInt64(sanitized, radix: 16) else {
            return .white
        }

        if sanitized.count == 8 {
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: CGFloat((value >> 24) & 0xFF) / 255
            )
        }

        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
