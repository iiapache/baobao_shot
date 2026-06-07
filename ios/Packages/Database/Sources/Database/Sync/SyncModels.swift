import Foundation

public struct RemoteFamilySnapshot: Sendable, Equatable {
    public let id: String
    public let name: String
    public let myRole: String
    public let updatedAt: Int64

    public init(id: String, name: String, myRole: String, updatedAt: Int64) {
        self.id = id
        self.name = name
        self.myRole = myRole
        self.updatedAt = updatedAt
    }
}

public struct RemoteMemberSnapshot: Sendable, Equatable {
    public let userId: String
    public let familyId: String
    public let role: String
    public let nickname: String?
    public let joinAt: Int64
    public let updatedAt: Int64

    public init(
        userId: String,
        familyId: String,
        role: String,
        nickname: String?,
        joinAt: Int64,
        updatedAt: Int64
    ) {
        self.userId = userId
        self.familyId = familyId
        self.role = role
        self.nickname = nickname
        self.joinAt = joinAt
        self.updatedAt = updatedAt
    }
}

public struct RemoteBabySnapshot: Sendable, Equatable {
    public let id: String
    public let familyId: String
    public let name: String
    public let gender: String?
    public let birthDate: String
    public let birthTime: String?
    public let avatarPath: String?
    public let updatedAt: Int64

    public init(
        id: String,
        familyId: String,
        name: String,
        gender: String? = nil,
        birthDate: String,
        birthTime: String? = nil,
        avatarPath: String? = nil,
        updatedAt: Int64
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.avatarPath = avatarPath
        self.updatedAt = updatedAt
    }

    public func toRecord() -> BabyRecord {
        BabyRecord(
            id: id,
            familyId: familyId,
            name: name,
            gender: gender,
            birthDate: birthDate,
            birthTime: birthTime,
            avatarPath: avatarPath,
            updatedAt: updatedAt
        )
    }
}

public struct SyncResult: Sendable, Equatable {
    public let familiesApplied: Int
    public let membersApplied: Int
    public let babiesApplied: Int
    public let syncedAt: Int64

    public init(familiesApplied: Int, membersApplied: Int, babiesApplied: Int, syncedAt: Int64) {
        self.familiesApplied = familiesApplied
        self.membersApplied = membersApplied
        self.babiesApplied = babiesApplied
        self.syncedAt = syncedAt
    }
}

public enum SyncEvent: Sendable, Equatable {
    case started
    case completed(SyncResult)
    case failed(String)
}
