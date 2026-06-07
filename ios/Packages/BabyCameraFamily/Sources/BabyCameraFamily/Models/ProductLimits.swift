import Foundation

/// 与 `docs/product-config.yaml` / auth-family-svc 常量对齐（OPT-05）。
public enum ProductLimits {
    public static let maxFamilyMembers = 8
    public static let maxBabiesPerFamily = 5
    public static let maxFamiliesCreated = 2
    public static let maxFamiliesJoined = 3

    public static let inviteCodeLength = 6
    public static let inviteTTLHours = 24
    public static let inviteMaxUses = 8

    public static let adminInactiveDays = 30
    public static let takeoverApprovalRatio = 0.5
    public static let takeoverObjectionDays = 7
}
