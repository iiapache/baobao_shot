import BabyCameraNetwork
import DesignSystem
import SwiftUI

public struct ConsentRestrictedView: View {
    private let feature: RestrictedFeature
    private let onOpenConsent: (() -> Void)?

    public init(feature: RestrictedFeature, onOpenConsent: (() -> Void)? = nil) {
        self.feature = feature
        self.onOpenConsent = onOpenConsent
    }

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(DSColors.warning)

            Text(L10n.localizedKey("onboarding.consent.restricted.title"))
                .font(DSTypography.title3)
                .foregroundStyle(DSColors.textPrimary)

            Text(feature.restrictionMessage)
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textSecondary)
                .multilineTextAlignment(.center)

            if let onOpenConsent {
                DSButton(L10n.string("onboarding.consent.restricted.action"), style: .primary) {
                    onOpenConsent()
                }
            }
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.background)
    }
}

public struct ConsentGatedContent<Content: View>: View {
    private let feature: RestrictedFeature
    private let profile: UserProfile?
    private let userId: String?
    private let onOpenConsent: (() -> Void)?
    private let content: () -> Content

    public init(
        feature: RestrictedFeature,
        profile: UserProfile?,
        userId: String? = nil,
        onOpenConsent: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.feature = feature
        self.profile = profile
        self.userId = userId
        self.onOpenConsent = onOpenConsent
        self.content = content
    }

    public var body: some View {
        if ChildDataConsentGate.isFeatureAllowed(feature, profile: profile, userId: userId) {
            content()
        } else {
            ConsentRestrictedView(feature: feature, onOpenConsent: onOpenConsent)
        }
    }
}
