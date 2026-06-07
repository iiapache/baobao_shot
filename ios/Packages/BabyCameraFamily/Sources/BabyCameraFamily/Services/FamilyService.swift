import BabyCameraNetwork
import Foundation

public enum FamilyServiceError: Error, Equatable, Sendable {
    case notAuthenticated
}

public struct FamilyServiceConfiguration: Sendable {
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
            deviceId: FamilyServiceConfiguration.resolveDeviceId()
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

public final class FamilyService: @unchecked Sendable {
    public let tokenStore: TokenStore
    public let region: AppRegion
    public let invitationCodeService: InvitationCodeService

    private let regionConfig: RegionConfig
    private let session: URLSession
    private let clientFactory: @Sendable (TokenStore) -> APIClient

    public init(
        configuration: FamilyServiceConfiguration = FamilyServiceConfiguration(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil
    ) {
        self.region = configuration.region
        self.regionConfig = configuration.regionConfig
        self.tokenStore = configuration.tokenStore
        self.session = configuration.session
        self.invitationCodeService = InvitationCodeService(signingSecret: configuration.inviteSigningSecret)
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
    }

    private func api() throws -> FamilyAPI {
        guard tokenStore.refreshToken() != nil else {
            throw FamilyServiceError.notAuthenticated
        }
        return FamilyAPI(client: clientFactory(tokenStore))
    }

    public func listFamilies() async throws -> [FamilySummary] {
        let items = try await api().listFamilies().items
        return items.map(FamilySummary.init(data:))
    }

    public func createFamily(name: String) async throws -> FamilySummary {
        FamilySummary(data: try await api().createFamily(name: name))
    }

    public func getFamily(familyId: String) async throws -> FamilyDetail {
        FamilyDetail(data: try await api().getFamily(familyId: familyId))
    }

    public func updateFamily(familyId: String, name: String) async throws -> FamilySummary {
        FamilySummary(data: try await api().updateFamily(familyId: familyId, name: name))
    }

    public func deleteFamily(familyId: String) async throws {
        _ = try await api().deleteFamily(familyId: familyId)
    }

    public func listMembers(familyId: String) async throws -> [FamilyMember] {
        do {
            let items = try await api().listMembers(familyId: familyId).items
            return items.map(FamilyMember.init(data:))
        } catch let error as APIError where error.httpStatusCode == 404 {
            let detail = try await getFamily(familyId: familyId)
            return detail.members
        }
    }

    public func updateMember(
        familyId: String,
        userId: String,
        role: FamilyRole? = nil,
        nickname: String? = nil
    ) async throws -> FamilyMember {
        let data = try await api().updateMember(
            familyId: familyId,
            userId: userId,
            role: role?.rawValue,
            nickname: nickname
        )
        return FamilyMember(
            id: data.userId,
            role: FamilyRole(apiValue: data.role ?? FamilyRole.family.rawValue),
            nickname: data.nickname ?? "",
            joinedAt: ""
        )
    }

    public func removeMember(familyId: String, userId: String) async throws {
        _ = try await api().removeMember(familyId: familyId, userId: userId)
    }

    public func createInvitation(familyId: String) async throws -> FamilyInvitation {
        FamilyInvitation(data: try await api().createInvitation(familyId: familyId))
    }

    public func revokeInvitation(familyId: String, code: String) async throws {
        _ = try await api().revokeInvitation(familyId: familyId, code: code)
    }

    public func joinFamily(code: String, relation: FamilyRelation, nickname: String?) async throws -> JoinFamilyResult {
        let trimmedNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (trimmedNickname?.isEmpty == false) ? trimmedNickname : nil
        return JoinFamilyResult(
            data: try await api().joinFamily(
                code: code,
                relation: relation.rawValue,
                nickname: displayName
            )
        )
    }

    public func joinFamily(fromScannedContent scanned: String, relation: FamilyRelation, nickname: String?) async throws -> JoinFamilyResult {
        let code = try invitationCodeService.extractInviteCode(from: scanned)
        return try await joinFamily(code: code, relation: relation, nickname: nickname)
    }

    public func transferAdmin(familyId: String, targetUserId: String) async throws -> TransferAdminResult {
        TransferAdminResult(data: try await api().transferAdmin(familyId: familyId, targetUserId: targetUserId))
    }

    public func takeover(familyId: String, choice: TakeoverBallotChoice? = nil) async throws -> TakeoverVoteResult {
        TakeoverVoteResult(data: try await api().takeover(familyId: familyId, choice: choice?.rawValue))
    }
}
