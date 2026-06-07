import Foundation

/// 家庭成员角色 — 与 JWT / API 对齐
public enum FamilyRole: String, Codable, Sendable, CaseIterable {
    case admin
    case family
    case guest

    public var displayName: String {
        switch self {
        case .admin: "管理员"
        case .family: "家庭成员"
        case .guest: "访客"
        }
    }

    public init(apiValue: String) {
        self = FamilyRole(rawValue: apiValue) ?? .family
    }
}
