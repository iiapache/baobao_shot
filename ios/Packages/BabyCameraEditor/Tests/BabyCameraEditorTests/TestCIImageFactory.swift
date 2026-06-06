import CoreImage
import Foundation

enum TestCIImageFactory {
    static func makeSolidColor(extent: CGRect, red: CGFloat = 0.5, green: CGFloat = 0.5, blue: CGFloat = 0.5) -> CIImage {
        let color = CIColor(red: red, green: green, blue: blue, alpha: 1)
        return CIFilter(name: "CIConstantColorGenerator", parameters: [kCIInputColorKey: color])!
            .outputImage!
            .cropped(to: extent)
    }
}
