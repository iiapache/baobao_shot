import CoreImage
import Foundation

/// 内置滤镜标识；T2.12 将扩展完整滤镜库。
public enum FilterIdentifier: String, Codable, CaseIterable, Sendable {
    case none
    case sepia
    case mono
    case vivid
    case fade
}

/// 滤镜步骤。
public struct FilterStep: EditStep {
    public var kind: EditStepKind { .filter }

    public var filterID: FilterIdentifier
    public var intensity: Double

    public init(filterID: FilterIdentifier, intensity: Double = 1.0) {
        self.filterID = filterID
        self.intensity = intensity
    }

    public func apply(to image: CIImage) -> CIImage {
        guard filterID != .none else { return image }

        let filterName: String
        switch filterID {
        case .none:
            return image
        case .sepia:
            filterName = "CISepiaTone"
        case .mono:
            filterName = "CIPhotoEffectMono"
        case .vivid:
            filterName = "CIPhotoEffectProcess"
        case .fade:
            filterName = "CIPhotoEffectFade"
        }

        guard let filter = CIFilter(name: filterName) else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)

        if filterID == .sepia {
            filter.setValue(intensity, forKey: kCIInputIntensityKey)
        }

        return filter.outputImage ?? image
    }
}
