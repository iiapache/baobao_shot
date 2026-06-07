import BabyCameraAccount
import BabyCameraBaby
import BabyCameraFamily
import BabyCameraNetwork
import Foundation

public protocol OnboardingServing: Sendable {
    func updateProfile(nickname: String) async throws -> AccountMeData
    func submitChildDataConsent(version: String, accepted: Bool) async throws -> ChildDataConsentData
    func createFamily(name: String) async throws -> FamilySummary
    func joinFamily(code: String, relation: FamilyRelation, nickname: String?) async throws -> JoinFamilyResult
    func joinFamily(fromScannedContent: String, relation: FamilyRelation, nickname: String?) async throws -> JoinFamilyResult
    func createBaby(familyId: String, profile: BabyProfile) async throws -> BabyProfile
    func refreshProfile() async throws -> AccountMeData
    func extractInviteCode(from content: String) throws -> String
}

public enum OnboardingServiceError: Error, Equatable, Sendable {
    case notAuthenticated
}

public struct OnboardingServiceConfiguration: Sendable {
    public let region: AppRegion
    public let regionConfig: RegionConfig
    public let tokenStore: TokenStore
    public let session: URLSession
    public let inviteSigningSecret: String?

    public init(
        region: AppRegion = .cn,
        regionConfig: RegionConfig? = nil,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared,
        inviteSigningSecret: String? = nil
    ) {
        self.region = region
        self.regionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: OnboardingServiceConfiguration.resolveDeviceId()
        )
        self.tokenStore = tokenStore
        self.session = session
        self.inviteSigningSecret = inviteSigningSecret
    }

    private static func resolveDeviceId() -> String {
        let key = "com.babycamera.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

public final class OnboardingService: @unchecked Sendable, OnboardingServing {
    private let familyService: FamilyService
    private let clientFactory: @Sendable (TokenStore) -> APIClient

    public init(configuration: OnboardingServiceConfiguration = OnboardingServiceConfiguration()) {
        self.familyService = FamilyService(
            configuration: FamilyServiceConfiguration(
                region: configuration.region,
                regionConfig: configuration.regionConfig,
                tokenStore: configuration.tokenStore,
                session: configuration.session,
                inviteSigningSecret: configuration.inviteSigningSecret
            )
        )
        self.clientFactory = { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
    }

    public init(familyService: FamilyService, clientFactory: @escaping @Sendable (TokenStore) -> APIClient) {
        self.familyService = familyService
        self.clientFactory = clientFactory
    }

    private func accountAPI() throws -> AccountAPI {
        guard familyService.tokenStore.refreshToken() != nil else {
            throw OnboardingServiceError.notAuthenticated
        }
        return AccountAPI(client: clientFactory(familyService.tokenStore))
    }

    private func babyService(familyId: String) -> BabyService {
        BabyService(
            familyId: familyId,
            client: clientFactory(familyService.tokenStore)
        )
    }

    public func updateProfile(nickname: String) async throws -> AccountMeData {
        try await accountAPI().updateMe(nickname: nickname)
    }

    public func submitChildDataConsent(version: String, accepted: Bool) async throws -> ChildDataConsentData {
        try await accountAPI().submitChildDataConsent(version: version, accepted: accepted)
    }

    public func createFamily(name: String) async throws -> FamilySummary {
        try await familyService.createFamily(name: name)
    }

    public func joinFamily(
        code: String,
        relation: FamilyRelation,
        nickname: String?
    ) async throws -> JoinFamilyResult {
        try await familyService.joinFamily(code: code, relation: relation, nickname: nickname)
    }

    public func joinFamily(
        fromScannedContent: String,
        relation: FamilyRelation,
        nickname: String?
    ) async throws -> JoinFamilyResult {
        try await familyService.joinFamily(
            fromScannedContent: fromScannedContent,
            relation: relation,
            nickname: nickname
        )
    }

    public func createBaby(familyId: String, profile: BabyProfile) async throws -> BabyProfile {
        try await babyService(familyId: familyId).createBaby(profile)
    }

    public func refreshProfile() async throws -> AccountMeData {
        try await accountAPI().getMe()
    }

    public func extractInviteCode(from content: String) throws -> String {
        try familyService.invitationCodeService.extractInviteCode(from: content)
    }
}
