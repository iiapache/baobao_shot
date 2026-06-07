import CoreImage
import Foundation

/// 相机实时滤镜库（T2.6：≥ 6 款预览滤镜）。
public enum RealtimeFilterCatalog {
    /// PRD / design-ios §7.2 要求的最低预览滤镜数量。
    public static let minimumPreviewFilterCount = 6

    public static let presets: [RealtimeFilterPreset] = [
        RealtimeFilterPreset(id: .none, displayName: "原图"),
        RealtimeFilterPreset(
            id: .sepia,
            displayName: "复古",
            ciFilterName: "CISepiaTone",
            intensityParameterKey: kCIInputIntensityKey,
            defaultIntensity: 0.85
        ),
        RealtimeFilterPreset(id: .mono, displayName: "黑白", ciFilterName: "CIPhotoEffectMono"),
        RealtimeFilterPreset(id: .vivid, displayName: "鲜明", ciFilterName: "CIPhotoEffectProcess"),
        RealtimeFilterPreset(id: .fade, displayName: "褪色", ciFilterName: "CIPhotoEffectFade"),
        RealtimeFilterPreset(id: .chrome, displayName: "铬黄", ciFilterName: "CIPhotoEffectChrome"),
        RealtimeFilterPreset(id: .instant, displayName: "即时", ciFilterName: "CIPhotoEffectInstant"),
        RealtimeFilterPreset(id: .noir, displayName: "暗调", ciFilterName: "CIPhotoEffectNoir"),
    ]

    /// 不含「原图」的预览滤镜列表，供 UI 横向选择器使用。
    public static var previewPresets: [RealtimeFilterPreset] {
        presets.filter { !$0.id.isOriginal }
    }

    public static func preset(for identifier: RealtimeFilterIdentifier) -> RealtimeFilterPreset {
        presets.first { $0.id == identifier } ?? presets[0]
    }

    /// 校验滤镜库是否满足 T2.6 最低数量要求。
    public static var satisfiesMinimumCount: Bool {
        previewPresets.count >= minimumPreviewFilterCount
    }
}
