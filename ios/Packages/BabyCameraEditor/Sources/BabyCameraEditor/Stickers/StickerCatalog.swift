import CoreImage
import Foundation

/// 贴纸资源加载协议；宿主 App 注入 Bundle / ODR 图片。
public protocol StickerAssetProviding: Sendable {
    func image(for stickerID: String) -> CIImage?
}

/// 编辑器贴纸库（T2.13：≥ 60 个，8 类分类，对接 design-assets/stickers/manifest.json）。
public enum StickerCatalog {
    public static let minimumStickerCount = 60
    public static let manifestResourceName = "stickers-manifest"

    /// 宿主可注入真实贴纸图片；未设置时使用占位合成。
    public static var imageProvider: (any StickerAssetProviding)?

    private static let manifest: StickerManifest = {
        do {
            return try DesignAssetManifestLoader.load(StickerManifest.self, resource: manifestResourceName)
        } catch {
            assertionFailure("Sticker manifest load failed: \(error)")
            return StickerManifest(schemaVersion: "0", categories: [], stickers: [])
        }
    }()

    public static let categories: [StickerCategory] = manifest.categories
        .map(StickerCategory.init)
        .sorted { $0.sort < $1.sort }

    public static let stickers: [StickerAsset] = manifest.stickers.map(StickerAsset.init)

    private static let stickersByID: [String: StickerAsset] = Dictionary(
        uniqueKeysWithValues: stickers.map { ($0.id, $0) }
    )

    private static let stickersByCategory: [StickerCategoryID: [StickerAsset]] = Dictionary(
        grouping: stickers,
        by: \.category
    )

    public static func sticker(for id: String) -> StickerAsset? {
        stickersByID[id]
    }

    public static func stickers(in category: StickerCategoryID) -> [StickerAsset] {
        stickersByCategory[category] ?? []
    }

    public static var satisfiesMinimumCount: Bool {
        stickers.count >= minimumStickerCount
    }

    public static var hasAllCategoriesRepresented: Bool {
        StickerCategoryID.allCases.allSatisfy { !(stickersByCategory[$0] ?? []).isEmpty }
    }

    /// 将 `StickerStep` 合成到画布；优先使用 `imageProvider`，否则占位色块。
    public static func apply(step: StickerStep, to image: CIImage) -> CIImage {
        let asset = sticker(for: step.resourceID)
        let effectiveScale = step.scale * (asset?.defaultScale ?? 1.0)
        let extent = image.extent
        let baseSize = min(extent.width, extent.height) * 0.15 * effectiveScale
        let center = CGPoint(
            x: extent.minX + extent.width * step.centerX,
            y: extent.minY + extent.height * step.centerY
        )

        let overlay: CIImage
        if let stickerImage = imageProvider?.image(for: step.resourceID) {
            let stickerExtent = stickerImage.extent
            let scaleFactor = baseSize / max(stickerExtent.width, stickerExtent.height)
            overlay = stickerImage
                .transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
                .transformed(by: CGAffineTransform(
                    translationX: center.x - stickerExtent.width * scaleFactor / 2,
                    y: center.y - stickerExtent.height * scaleFactor / 2
                ))
        } else {
            let stickerRect = CGRect(
                x: center.x - baseSize / 2,
                y: center.y - baseSize / 2,
                width: baseSize,
                height: baseSize
            )
            guard let placeholder = CIFilter(
                name: "CIConstantColorGenerator",
                parameters: [
                    kCIInputColorKey: CIColor(red: 1, green: 0.8, blue: 0.2, alpha: 0.6),
                ]
            )?.outputImage?.cropped(to: stickerRect) else {
                return image
            }
            overlay = placeholder
        }

        let rotated = overlay.transformed(by: CGAffineTransform(rotationAngle: step.rotationDegrees * .pi / 180))
        return rotated.composited(over: image)
    }
}
