import BabyCameraNetwork
import Foundation

public struct FamilySummary: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let role: FamilyRole

    public init(id: String, name: String, role: FamilyRole) {
        self.id = id
        self.name = name
        self.role = role
    }

    init(data: FamilySummaryData) {
        self.init(
            id: data.familyId,
            name: data.name,
            role: FamilyRole(apiValue: data.role)
        )
    }
}

public struct FamilyMember: Sendable, Equatable, Identifiable {
    public let id: String
    public let role: FamilyRole
    public let nickname: String
    public let joinedAt: String

    public init(id: String, role: FamilyRole, nickname: String, joinedAt: String) {
        self.id = id
        self.role = role
        self.nickname = nickname
        self.joinedAt = joinedAt
    }

    init(data: FamilyMemberData) {
        self.init(
            id: data.userId,
            role: FamilyRole(apiValue: data.role),
            nickname: data.nickname ?? "",
            joinedAt: data.joinedAt
        )
    }
}

public struct FamilyDetail: Sendable, Equatable {
    public let id: String
    public let name: String
    public let role: FamilyRole
    public let members: [FamilyMember]

    public init(id: String, name: String, role: FamilyRole, members: [FamilyMember]) {
        self.id = id
        self.name = name
        self.role = role
        self.members = members
    }

    init(data: FamilyDetailData) {
        self.init(
            id: data.familyId,
            name: data.name,
            role: FamilyRole(apiValue: data.role),
            members: data.members.map(FamilyMember.init(data:))
        )
    }
}

public struct InviteQRPayload: Codable, Sendable, Equatable {
    public let scheme: String
    public let code: String
    public let sig: String

    public init(scheme: String, code: String, sig: String) {
        self.scheme = scheme
        self.code = code
        self.sig = sig
    }

    init(data: InviteQRPayloadData) {
        self.init(scheme: data.scheme, code: data.code, sig: data.sig)
    }

    var apiData: InviteQRPayloadData {
        InviteQRPayloadData(scheme: scheme, code: code, sig: sig)
    }
}

public struct FamilyInvitation: Sendable, Equatable {
    public let code: String
    public let expireAt: String
    public let maxUses: Int
    public let usedCount: Int
    public let qrPayload: InviteQRPayload

    public init(
        code: String,
        expireAt: String,
        maxUses: Int,
        usedCount: Int,
        qrPayload: InviteQRPayload
    ) {
        self.code = code
        self.expireAt = expireAt
        self.maxUses = maxUses
        self.usedCount = usedCount
        self.qrPayload = qrPayload
    }

    init(data: InvitationData) {
        self.init(
            code: data.code,
            expireAt: data.expireAt,
            maxUses: data.maxUses,
            usedCount: data.usedCount,
            qrPayload: InviteQRPayload(data: data.qrPayload)
        )
    }
}

public struct JoinFamilyResult: Sendable, Equatable {
    public let familyId: String
    public let role: FamilyRole
    public let joinedAt: String

    public init(familyId: String, role: FamilyRole, joinedAt: String) {
        self.familyId = familyId
        self.role = role
        self.joinedAt = joinedAt
    }

    init(data: JoinFamilyData) {
        self.init(
            familyId: data.familyId,
            role: FamilyRole(apiValue: data.role),
            joinedAt: data.joinedAt
        )
    }
}

public struct TransferAdminResult: Sendable, Equatable {
    public let familyId: String
    public let previousAdminUserId: String
    public let newAdminUserId: String
    public let transferredAt: String

    public init(
        familyId: String,
        previousAdminUserId: String,
        newAdminUserId: String,
        transferredAt: String
    ) {
        self.familyId = familyId
        self.previousAdminUserId = previousAdminUserId
        self.newAdminUserId = newAdminUserId
        self.transferredAt = transferredAt
    }

    init(data: TransferAdminData) {
        self.init(
            familyId: data.familyId,
            previousAdminUserId: data.previousAdminUserId,
            newAdminUserId: data.newAdminUserId,
            transferredAt: data.transferredAt
        )
    }
}

public enum TakeoverVoteStatus: String, Sendable, Equatable {
    case voting
    case objectionPeriod = "objection_period"
    case completed
    case cancelled
    case rejected

    public init(apiValue: String) {
        self = TakeoverVoteStatus(rawValue: apiValue) ?? .voting
    }
}

public enum TakeoverBallotChoice: String, Sendable {
    case approve
    case reject
}

public struct TakeoverVoteResult: Sendable, Equatable {
    public let voteId: String
    public let status: TakeoverVoteStatus
    public let initiatorUserId: String
    public let eligibleVoters: Int
    public let approveCount: Int
    public let rejectCount: Int
    public let requiredApprovals: Int
    public let objectionEndsAt: String?

    public init(
        voteId: String,
        status: TakeoverVoteStatus,
        initiatorUserId: String,
        eligibleVoters: Int,
        approveCount: Int,
        rejectCount: Int,
        requiredApprovals: Int,
        objectionEndsAt: String? = nil
    ) {
        self.voteId = voteId
        self.status = status
        self.initiatorUserId = initiatorUserId
        self.eligibleVoters = eligibleVoters
        self.approveCount = approveCount
        self.rejectCount = rejectCount
        self.requiredApprovals = requiredApprovals
        self.objectionEndsAt = objectionEndsAt
    }

    init(data: TakeoverVoteData) {
        self.init(
            voteId: data.voteId,
            status: TakeoverVoteStatus(apiValue: data.status),
            initiatorUserId: data.initiatorUserId,
            eligibleVoters: data.eligibleVoters,
            approveCount: data.approveCount,
            rejectCount: data.rejectCount,
            requiredApprovals: data.requiredApprovals,
            objectionEndsAt: data.objectionEndsAt
        )
    }

    public var isActive: Bool {
        status == .voting || status == .objectionPeriod
    }
}
