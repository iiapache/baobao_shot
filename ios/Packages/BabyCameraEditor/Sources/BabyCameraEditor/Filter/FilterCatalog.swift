import CoreImage
import Foundation

/// 编辑器滤镜库（T2.12：≥ 12 款，四类分类）。
public enum FilterCatalog {
    public static let minimumFilterCount = 12

    public static let presets: [FilterPreset] = [
        FilterPreset(id: .none, category: .daily, displayName: "原图"),

        // 日常
        FilterPreset(id: .vivid, category: .daily, displayName: "鲜明", ciFilterName: "CIPhotoEffectProcess"),
        FilterPreset(id: .fade, category: .daily, displayName: "褪色", ciFilterName: "CIPhotoEffectFade"),
        FilterPreset(id: .instant, category: .daily, displayName: "即时", ciFilterName: "CIPhotoEffectInstant"),

        // 人像
        FilterPreset(id: .mono, category: .portrait, displayName: "黑白", ciFilterName: "CIPhotoEffectMono"),
        FilterPreset(id: .transfer, category: .portrait, displayName: "质感", ciFilterName: "CIPhotoEffectTransfer"),
        FilterPreset(id: .softGlow, category: .portrait, displayName: "柔光", ciFilterName: "CIHighlightShadowAdjust"),

        // 胶片
        FilterPreset(
            id: .sepia,
            category: .film,
            displayName: "复古",
            ciFilterName: "CISepiaTone",
            intensityParameterKey: kCIInputIntensityKey,
            defaultIntensity: 0.85
        ),
        FilterPreset(id: .chrome, category: .film, displayName: "铬黄", ciFilterName: "CIPhotoEffectChrome"),
        FilterPreset(id: .tonal, category: .film, displayName: "色调", ciFilterName: "CIPhotoEffectTonal"),
        FilterPreset(id: .noir, category: .film, displayName: "暗调", ciFilterName: "CIPhotoEffectNoir"),

        // 卡通
        FilterPreset(
            id: .posterize,
            category: .cartoon,
            displayName: "色块",
            ciFilterName: "CIColorPosterize",
            intensityParameterKey: "inputLevels",
            defaultIntensity: 0.6
        ),
        FilterPreset(id: .comic, category: .cartoon, displayName: "漫画", ciFilterName: "CIComicEffect"),
        FilterPreset(id: .sketch, category: .cartoon, displayName: "素描", ciFilterName: "CILineOverlay"),
    ]

    /// 不含「原图」的滤镜列表。
    public static var editablePresets: [FilterPreset] {
        presets.filter { $0.id != .none }
    }

    public static func preset(for identifier: FilterIdentifier) -> FilterPreset {
        presets.first { $0.id == identifier } ?? presets[0]
    }

    public static func presets(in category: FilterCategory) -> [FilterPreset] {
        presets.filter { $0.category == category && $0.id != .none }
    }

    public static func category(for identifier: FilterIdentifier) -> FilterCategory {
        preset(for: identifier).category
    }

    public static var satisfiesMinimumCount: Bool {
        editablePresets.count >= minimumFilterCount
    }

    /// 校验四类分类均至少有一款滤镜。
    public static var hasAllCategoriesRepresented: Bool {
        FilterCategory.allCases.allSatisfy { !presets(in: $0).isEmpty }
    }

    /// 将 `FilterStep` 应用到 `CIImage`。
    public static func apply(step: FilterStep, to image: CIImage) -> CIImage {
        let preset = preset(for: step.filterID)
        guard preset.id != .none else { return image }
        guard let filterName = preset.ciFilterName,
              let filter = CIFilter(name: filterName) else { return image }

        filter.setValue(image, forKey: kCIInputImageKey)
        applyFixedParameters(for: preset.id, to: filter)

        let clampedIntensity = step.intensity.clamped(to: 0...1)

        if let intensityKey = preset.intensityParameterKey {
            let mapped = mapIntensity(clampedIntensity, for: preset)
            filter.setValue(mapped, forKey: intensityKey)
        }

        guard let filtered = filter.outputImage else { return image }

        if preset.usesBuiltInIntensityParameter {
            return filtered
        }

        return blend(original: image, filtered: filtered, amount: clampedIntensity)
    }

    private static func applyFixedParameters(for identifier: FilterIdentifier, to filter: CIFilter) {
        switch identifier {
        case .softGlow:
            filter.setValue(0.35, forKey: "inputShadowAmount")
            filter.setValue(-0.15, forKey: "inputHighlightAmount")
        case .sketch:
            filter.setValue(0.07, forKey: "inputNRNoiseLevel")
            filter.setValue(0.71, forKey: "inputNRSharpness")
        default:
            break
        }
    }

    private static func mapIntensity(_ intensity: Double, for preset: FilterPreset) -> Double {
        switch preset.id {
        case .posterize:
            return 4 + (1 - intensity) * 16
        case .sepia:
            return intensity * preset.defaultIntensity
        default:
            return intensity
        }
    }

    private static func blend(original: CIImage, filtered: CIImage, amount: Double) -> CIImage {
        guard amount < 1 else { return filtered }
        guard amount > 0 else { return original }

        let maskColor = CIColor(red: CGFloat(amount), green: CGFloat(amount), blue: CGFloat(amount))
        let mask = CIImage(color: maskColor).cropped(to: original.extent)

        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return filtered }
        blendFilter.setValue(filtered, forKey: kCIInputImageKey)
        blendFilter.setValue(original, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        return blendFilter.outputImage ?? filtered
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
