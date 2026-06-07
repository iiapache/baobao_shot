import Foundation

/// 品牌水印显示策略：与订阅权益联动（T2.16 / PRD §4.10.2）。
public protocol BrandWatermarkPolicy: Sendable {
    /// 是否应在输出图像上合成品牌水印。
    /// - Parameter isSubscribed: 当前用户是否为有效订阅用户。
    func shouldShowBrandWatermark(isSubscribed: Bool) -> Bool
}

/// 默认策略：非订阅用户强制显示；订阅用户由 `brandWatermarkEnabled` 决定是否显示。
public struct SubscriptionBrandWatermarkPolicy: BrandWatermarkPolicy {
    private let brandWatermarkEnabled: @Sendable () -> Bool

    public init(brandWatermarkEnabled: @escaping @Sendable () -> Bool = { true }) {
        self.brandWatermarkEnabled = brandWatermarkEnabled
    }

    public func shouldShowBrandWatermark(isSubscribed: Bool) -> Bool {
        guard isSubscribed else { return true }
        return brandWatermarkEnabled()
    }
}

/// 测试 / 预览用：始终显示品牌水印。
public struct AlwaysShowBrandWatermarkPolicy: BrandWatermarkPolicy {
    public init() {}

    public func shouldShowBrandWatermark(isSubscribed: Bool) -> Bool {
        true
    }
}

/// 测试 / 预览用：始终隐藏品牌水印。
public struct NeverShowBrandWatermarkPolicy: BrandWatermarkPolicy {
    public init() {}

    public func shouldShowBrandWatermark(isSubscribed: Bool) -> Bool {
        false
    }
}
