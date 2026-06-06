import CoreImage
import Foundation

/// 类型擦除容器，支持 `[AnyEditStep]` 作为单一事实源。
public enum AnyEditStep: EditStep, Sendable {
    case filter(FilterStep)
    case adjust(AdjustStep)
    case crop(CropStep)
    case rotate(RotateStep)
    case sticker(StickerStep)
    case text(TextStep)
    case mosaic(MosaicStep)
    case doodle(DoodleStep)
    case template(TemplateStep)

    public var kind: EditStepKind {
        switch self {
        case .filter: .filter
        case .adjust: .adjust
        case .crop: .crop
        case .rotate: .rotate
        case .sticker: .sticker
        case .text: .text
        case .mosaic: .mosaic
        case .doodle: .doodle
        case .template: .template
        }
    }

    public func apply(to image: CIImage) -> CIImage {
        switch self {
        case let .filter(step): step.apply(to: image)
        case let .adjust(step): step.apply(to: image)
        case let .crop(step): step.apply(to: image)
        case let .rotate(step): step.apply(to: image)
        case let .sticker(step): step.apply(to: image)
        case let .text(step): step.apply(to: image)
        case let .mosaic(step): step.apply(to: image)
        case let .doodle(step): step.apply(to: image)
        case let .template(step): step.apply(to: image)
        }
    }

    public init<S: EditStep>(_ step: S) {
        switch step {
        case let filter as FilterStep: self = .filter(filter)
        case let adjust as AdjustStep: self = .adjust(adjust)
        case let crop as CropStep: self = .crop(crop)
        case let rotate as RotateStep: self = .rotate(rotate)
        case let sticker as StickerStep: self = .sticker(sticker)
        case let text as TextStep: self = .text(text)
        case let mosaic as MosaicStep: self = .mosaic(mosaic)
        case let doodle as DoodleStep: self = .doodle(doodle)
        case let template as TemplateStep: self = .template(template)
        default:
            fatalError("Unsupported EditStep type: \(type(of: step))")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(EditStepKind.self, forKey: .kind)

        switch kind {
        case .filter:
            self = .filter(try container.decode(FilterStep.self, forKey: .payload))
        case .adjust:
            self = .adjust(try container.decode(AdjustStep.self, forKey: .payload))
        case .crop:
            self = .crop(try container.decode(CropStep.self, forKey: .payload))
        case .rotate:
            self = .rotate(try container.decode(RotateStep.self, forKey: .payload))
        case .sticker:
            self = .sticker(try container.decode(StickerStep.self, forKey: .payload))
        case .text:
            self = .text(try container.decode(TextStep.self, forKey: .payload))
        case .mosaic:
            self = .mosaic(try container.decode(MosaicStep.self, forKey: .payload))
        case .doodle:
            self = .doodle(try container.decode(DoodleStep.self, forKey: .payload))
        case .template:
            self = .template(try container.decode(TemplateStep.self, forKey: .payload))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)

        switch self {
        case let .filter(step):
            try container.encode(step, forKey: .payload)
        case let .adjust(step):
            try container.encode(step, forKey: .payload)
        case let .crop(step):
            try container.encode(step, forKey: .payload)
        case let .rotate(step):
            try container.encode(step, forKey: .payload)
        case let .sticker(step):
            try container.encode(step, forKey: .payload)
        case let .text(step):
            try container.encode(step, forKey: .payload)
        case let .mosaic(step):
            try container.encode(step, forKey: .payload)
        case let .doodle(step):
            try container.encode(step, forKey: .payload)
        case let .template(step):
            try container.encode(step, forKey: .payload)
        }
    }
}
