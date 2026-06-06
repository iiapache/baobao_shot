import BabyCameraNetwork
import Foundation

public struct AuthSession: Sendable, Equatable {
    public let userId: String
    public let isNewUser: Bool
    public let profile: UserProfile?

    public init(userId: String, isNewUser: Bool, profile: UserProfile?) {
        self.userId = userId
        self.isNewUser = isNewUser
        self.profile = profile
    }

    init(loginData: AuthLoginData) {
        self.userId = loginData.userId
        self.isNewUser = loginData.isNewUser
        self.profile = loginData.profile
    }

    init(me: AccountMeData, isNewUser: Bool = false) {
        self.userId = me.userId
        self.isNewUser = isNewUser
        self.profile = UserProfile(
            nickname: me.nickname,
            avatarUrl: me.avatarUrl,
            region: me.region,
            consents: me.consents
        )
    }
}

public struct AccountDeletionResult: Sendable, Equatable {
    public let requestedAt: String
    public let scheduledAt: String
    public let revokeBefore: String

    init(data: AccountDeletionData) {
        self.requestedAt = data.requestedAt
        self.scheduledAt = data.scheduledAt
        self.revokeBefore = data.revokeBefore
    }
}
