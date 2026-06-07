import Foundation

/// 编辑器工具栏面板（T2.12 滤镜/调色/裁剪/旋转；T2.13 贴纸/文字/马赛克/涂鸦）。
public enum EditorToolbarPanel: String, CaseIterable, Sendable {
    case filter
    case adjust
    case crop
    case rotate
    case sticker
    case text
    case mosaic
    case doodle

    public var displayName: String {
        switch self {
        case .filter: "滤镜"
        case .adjust: "调色"
        case .crop: "裁剪"
        case .rotate: "旋转"
        case .sticker: "贴纸"
        case .text: "文字"
        case .mosaic: "马赛克"
        case .doodle: "涂鸦"
        }
    }
}

/// 滤镜面板 UI 绑定状态。
public struct FilterPanelBinding: Equatable, Sendable {
    public var category: FilterCategory
    public var filterID: FilterIdentifier
    /// 0…1
    public var intensity: Double

    public init(
        category: FilterCategory = .daily,
        filterID: FilterIdentifier = .vivid,
        intensity: Double = 1.0
    ) {
        self.category = category
        self.filterID = filterID
        self.intensity = intensity
    }

    public var availablePresets: [FilterPreset] {
        FilterCatalog.presets(in: category)
    }

    public mutating func selectCategory(_ newCategory: FilterCategory) {
        category = newCategory
        if !availablePresets.contains(where: { $0.id == filterID }) {
            filterID = availablePresets.first?.id ?? .none
            intensity = FilterCatalog.preset(for: filterID).defaultIntensity
        }
    }

    public mutating func selectFilter(_ identifier: FilterIdentifier) {
        filterID = identifier
        category = FilterCatalog.category(for: identifier)
        intensity = FilterCatalog.preset(for: identifier).defaultIntensity
    }

    public func makeStep() -> FilterStep {
        FilterStep(filterID: filterID, intensity: intensity)
    }
}

/// 调色面板 UI 绑定状态。
public struct AdjustPanelBinding: Equatable, Sendable {
    public var parameters: AdjustParameters

    public init(parameters: AdjustParameters = AdjustParameters()) {
        self.parameters = parameters
    }

    public mutating func setNormalizedValue(_ normalized: Double, for keyPath: WritableKeyPath<AdjustParameters, Double>, range: AdjustParameterRanges.Range) {
        parameters[keyPath: keyPath] = range.denormalized(normalized)
    }

    public func normalizedValue(for keyPath: KeyPath<AdjustParameters, Double>, range: AdjustParameterRanges.Range) -> Double {
        range.normalized(parameters[keyPath: keyPath])
    }

    public func makeStep() -> AdjustStep {
        AdjustStep(parameters: parameters.clamped())
    }

    public mutating func reset() {
        parameters = AdjustParameters()
    }
}

/// 裁剪面板 UI 绑定状态。
public struct CropPanelBinding: Equatable, Sendable {
    public var aspectRatio: CropAspectRatio
    public var rect: NormalizedRect

    public init(
        aspectRatio: CropAspectRatio = .free,
        rect: NormalizedRect = .full
    ) {
        self.aspectRatio = aspectRatio
        self.rect = rect
    }

    public mutating func selectAspectRatio(_ ratio: CropAspectRatio) {
        aspectRatio = ratio
        rect = NormalizedRect.centered(aspectRatio: ratio)
    }

    public func makeStep() -> CropStep {
        CropStep(rect: rect, aspectRatio: aspectRatio)
    }
}

/// 旋转面板 UI 绑定状态。
public struct RotatePanelBinding: Equatable, Sendable {
    public var degrees: Double
    public var mirrorHorizontal: Bool
    public var mirrorVertical: Bool

    public init(
        degrees: Double = 0,
        mirrorHorizontal: Bool = false,
        mirrorVertical: Bool = false
    ) {
        self.degrees = degrees
        self.mirrorHorizontal = mirrorHorizontal
        self.mirrorVertical = mirrorVertical
    }

    public mutating func rotate90Clockwise() {
        let step = RotateStep.rotate90Clockwise(
            from: RotateStep(
                degrees: degrees,
                mirrorHorizontal: mirrorHorizontal,
                mirrorVertical: mirrorVertical
            )
        )
        degrees = step.degrees
        mirrorHorizontal = step.mirrorHorizontal
        mirrorVertical = step.mirrorVertical
    }

    public mutating func toggleMirrorHorizontal() {
        mirrorHorizontal.toggle()
    }

    public mutating func toggleMirrorVertical() {
        mirrorVertical.toggle()
    }

    public func makeStep() -> RotateStep {
        RotateStep(
            degrees: degrees,
            mirrorHorizontal: mirrorHorizontal,
            mirrorVertical: mirrorVertical
        )
    }
}

/// 贴纸面板 UI 绑定状态。
public struct StickerPanelBinding: Equatable, Sendable {
    public var category: StickerCategoryID
    public var stickerID: String
    public var centerX: Double
    public var centerY: Double
    public var scale: Double
    public var rotationDegrees: Double

    public init(
        category: StickerCategoryID = .cute,
        stickerID: String? = nil,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        scale: Double = 1.0,
        rotationDegrees: Double = 0
    ) {
        self.category = category
        let defaultID = stickerID ?? StickerCatalog.stickers(in: category).first?.id ?? ""
        self.stickerID = defaultID
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
    }

    public var availableStickers: [StickerAsset] {
        StickerCatalog.stickers(in: category)
    }

    public var selectedSticker: StickerAsset? {
        StickerCatalog.sticker(for: stickerID)
    }

    public mutating func selectCategory(_ newCategory: StickerCategoryID) {
        category = newCategory
        if !availableStickers.contains(where: { $0.id == stickerID }) {
            stickerID = availableStickers.first?.id ?? stickerID
        }
    }

    public mutating func selectSticker(_ id: String) {
        stickerID = id
        if let asset = StickerCatalog.sticker(for: id) {
            category = asset.category
        }
    }

    public func makeStep() -> StickerStep {
        StickerStep(
            resourceID: stickerID,
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            rotationDegrees: rotationDegrees
        )
    }
}

/// 文字面板 UI 绑定状态。
public struct TextPanelBinding: Equatable, Sendable {
    public var text: String
    public var fontID: String
    public var fontSize: Double
    public var colorHex: String
    public var centerX: Double
    public var centerY: Double

    public init(
        text: String = "宝宝百天",
        fontID: String = FontCatalog.defaultFontID,
        fontSize: Double = 24,
        colorHex: String = "#FFFFFF",
        centerX: Double = 0.5,
        centerY: Double = 0.9
    ) {
        self.text = text
        self.fontID = fontID
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.centerX = centerX
        self.centerY = centerY
    }

    public var availableFonts: [FontAsset] {
        FontCatalog.allEditorFonts
    }

    public var selectedFont: FontAsset? {
        FontCatalog.font(for: fontID)
    }

    public mutating func selectFont(_ id: String) {
        fontID = id
    }

    public func makeStep() -> TextStep {
        TextStep(
            text: text,
            fontName: FontCatalog.postScriptName(for: fontID),
            fontID: fontID,
            fontSize: fontSize,
            colorHex: colorHex,
            centerX: centerX,
            centerY: centerY
        )
    }
}

/// 马赛克面板 UI 绑定状态。
public struct MosaicPanelBinding: Equatable, Sendable {
    public static let defaultBlockSize = 16.0
    public static let minBlockSize = 4.0
    public static let maxBlockSize = 64.0

    public var region: NormalizedRect
    public var blockSize: Double

    public init(
        region: NormalizedRect = NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
        blockSize: Double = defaultBlockSize
    ) {
        self.region = region
        self.blockSize = blockSize
    }

    public mutating func setNormalizedBlockSize(_ normalized: Double) {
        let clamped = min(max(normalized, 0), 1)
        blockSize = MosaicPanelBinding.minBlockSize
            + clamped * (MosaicPanelBinding.maxBlockSize - MosaicPanelBinding.minBlockSize)
    }

    public var normalizedBlockSize: Double {
        (blockSize - MosaicPanelBinding.minBlockSize)
            / (MosaicPanelBinding.maxBlockSize - MosaicPanelBinding.minBlockSize)
    }

    public func makeStep() -> MosaicStep {
        MosaicStep(region: region, blockSize: blockSize)
    }
}

/// 涂鸦面板 UI 绑定状态。
public struct DoodlePanelBinding: Equatable, Sendable {
    public var strokeColorHex: String
    public var strokeWidth: Double
    public var points: [DoodlePoint]

    public init(
        strokeColorHex: String = "#FF0000",
        strokeWidth: Double = 4,
        points: [DoodlePoint] = []
    ) {
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth
        self.points = points
    }

    public var hasStroke: Bool {
        points.count >= 2
    }

    public mutating func appendPoint(_ point: DoodlePoint) {
        points.append(point)
    }

    public mutating func clearStroke() {
        points.removeAll()
    }

    public func makeStep() -> DoodleStep {
        DoodleStep(
            strokeColorHex: strokeColorHex,
            strokeWidth: strokeWidth,
            points: points
        )
    }
}

/// 工具栏总绑定：面板切换 + 各子面板状态 + 提交到 `EditorState`。
public struct EditorToolbarBinding: Equatable, Sendable {
    public var activePanel: EditorToolbarPanel
    public var filter: FilterPanelBinding
    public var adjust: AdjustPanelBinding
    public var crop: CropPanelBinding
    public var rotate: RotatePanelBinding
    public var sticker: StickerPanelBinding
    public var text: TextPanelBinding
    public var mosaic: MosaicPanelBinding
    public var doodle: DoodlePanelBinding

    public init(
        activePanel: EditorToolbarPanel = .filter,
        filter: FilterPanelBinding = FilterPanelBinding(),
        adjust: AdjustPanelBinding = AdjustPanelBinding(),
        crop: CropPanelBinding = CropPanelBinding(),
        rotate: RotatePanelBinding = RotatePanelBinding(),
        sticker: StickerPanelBinding = StickerPanelBinding(),
        text: TextPanelBinding = TextPanelBinding(),
        mosaic: MosaicPanelBinding = MosaicPanelBinding(),
        doodle: DoodlePanelBinding = DoodlePanelBinding()
    ) {
        self.activePanel = activePanel
        self.filter = filter
        self.adjust = adjust
        self.crop = crop
        self.rotate = rotate
        self.sticker = sticker
        self.text = text
        self.mosaic = mosaic
        self.doodle = doodle
    }

    public mutating func commitActivePanel(to editorState: EditorState) {
        switch activePanel {
        case .filter:
            editorState.append(filter.makeStep())
        case .adjust:
            let step = adjust.makeStep()
            guard !step.parameters.isNeutral else { return }
            editorState.append(step)
        case .crop:
            editorState.append(crop.makeStep())
        case .rotate:
            let step = rotate.makeStep()
            guard !step.isIdentity else { return }
            editorState.append(step)
        case .sticker:
            guard StickerCatalog.sticker(for: sticker.stickerID) != nil else { return }
            editorState.append(sticker.makeStep())
        case .text:
            let trimmed = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            editorState.append(text.makeStep())
        case .mosaic:
            editorState.append(mosaic.makeStep())
        case .doodle:
            guard doodle.hasStroke else { return }
            editorState.append(doodle.makeStep())
            doodle.clearStroke()
        }
    }
}
