import Foundation

public protocol SubscriptionServing: AnyObject {
    var state: SubscriptionState { get }
    var entitlements: SubscriptionEntitlements { get }
    var isActive: Bool { get }
    var isEntitled: Bool { get }
    var shouldShowAds: Bool { get }
    var brandWatermarkVisible: Bool { get }

    func refreshIfNeeded() async throws
    func refresh() async throws
    func setBrandWatermarkVisible(_ visible: Bool)
    func watermarkIsSubscribed() -> Bool
    func watermarkBrandEnabled() -> Bool
}
