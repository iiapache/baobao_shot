import BabyCameraAccount
import BabyCameraOnboarding

extension AuthSession {
    func allows(_ feature: RestrictedFeature) -> Bool {
        ChildDataConsentGate.isFeatureAllowed(feature, profile: profile, userId: userId)
    }
}
