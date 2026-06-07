import CoreImage
import Foundation

enum ColorHex {
    static func ciColor(from hex: String, defaultAlpha: CGFloat = 1) -> CIColor {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }

        guard sanitized.count == 6 || sanitized.count == 8,
              let value = UInt64(sanitized, radix: 16) else {
            return CIColor(red: 1, green: 1, blue: 1, alpha: defaultAlpha)
        }

        if sanitized.count == 8 {
            let alpha = CGFloat((value >> 24) & 0xFF) / 255
            let red = CGFloat((value >> 16) & 0xFF) / 255
            let green = CGFloat((value >> 8) & 0xFF) / 255
            let blue = CGFloat(value & 0xFF) / 255
            return CIColor(red: red, green: green, blue: blue, alpha: alpha)
        }

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return CIColor(red: red, green: green, blue: blue, alpha: defaultAlpha)
    }
}
