import Foundation

/// 与 design-api §12 对齐的错误码
public enum APIErrorCode: String, Codable, Sendable, CaseIterable {
    case ok = "OK"

    // COMMON_*
    case commonBadParam = "COMMON_BAD_PARAM"
    case commonRateLimit = "COMMON_RATE_LIMIT"
    case commonForbidden = "COMMON_FORBIDDEN"
    case commonNotFound = "COMMON_NOT_FOUND"
    case commonConflict = "COMMON_CONFLICT"

    // AUTH_*
    case authTokenExpired = "AUTH_TOKEN_EXPIRED"
    case authRefreshInvalid = "AUTH_REFRESH_INVALID"
    case authDeviceMismatch = "AUTH_DEVICE_MISMATCH"
    case authUnauthorized = "AUTH_UNAUTHORIZED"

    // ACCOUNT_*
    case accountConsentRequired = "ACCOUNT_CONSENT_REQUIRED"

    // FAMILY_*
    case familyInviteExpired = "FAMILY_INVITE_EXPIRED"
    case familyInviteUsedUp = "FAMILY_INVITE_USED_UP"
    case familyMemberLimit = "FAMILY_MEMBER_LIMIT"
    case familyNotAdmin = "FAMILY_NOT_ADMIN"

    // BABY_*
    case babyNotFound = "BABY_NOT_FOUND"

    // UPLOAD_*
    case uploadObjectExpired = "UPLOAD_OBJECT_EXPIRED"

    // AI_*
    case aiInsufficientCredit = "AI_INSUFFICIENT_CREDIT"
    case aiPlayNotAvailable = "AI_PLAY_NOT_AVAILABLE"
    case aiInputNotFound = "AI_INPUT_NOT_FOUND"
    case aiRateLimited = "AI_RATE_LIMITED"
    case aiAuditRejected = "AI_AUDIT_REJECTED"

    // POST_*
    case postItemLimit = "POST_ITEM_LIMIT"
    case postAuditRejected = "POST_AUDIT_REJECTED"

    // CREDIT_*
    case creditSignInDone = "CREDIT_SIGN_IN_DONE"

    // IAP_*
    case iapVerifyFailed = "IAP_VERIFY_FAILED"
    case iapUserMismatch = "IAP_USER_MISMATCH"

    // SUB_*
    case subProductNotFound = "SUB_PRODUCT_NOT_FOUND"

    // AUDIT_*
    case auditRejected = "AUDIT_REJECTED"

    // BACKUP_*
    case backupAuthRevoked = "BACKUP_AUTH_REVOKED"

    // NOTIF_*
    case notifTokenInvalid = "NOTIF_TOKEN_INVALID"

    // CAPTION_*
    case captionDailyLimit = "CAPTION_DAILY_LIMIT"

    // SYS_*
    case sysInternal = "SYS_INTERNAL"
    case sysUpstreamUnavailable = "SYS_UPSTREAM_UNAVAILABLE"

    case unknown

    public init(rawCode: String) {
        self = APIErrorCode(rawValue: rawCode) ?? .unknown
    }
}

public struct APIError: Error, Sendable, Equatable {
    public let code: APIErrorCode
    public let rawCode: String
    public let message: String
    public let requestId: String?
    public let httpStatusCode: Int?

    public init(
        code: APIErrorCode,
        rawCode: String? = nil,
        message: String,
        requestId: String? = nil,
        httpStatusCode: Int? = nil
    ) {
        self.code = code
        self.rawCode = rawCode ?? code.rawValue
        self.message = message
        self.requestId = requestId
        self.httpStatusCode = httpStatusCode
    }

    public var isTokenExpired: Bool { code == .authTokenExpired }
    public var requiresReLogin: Bool {
        switch code {
        case .authRefreshInvalid, .authDeviceMismatch, .authUnauthorized:
            return true
        default:
            return false
        }
    }
}

public enum NetworkTransportError: Error, Sendable, Equatable {
    case invalidURL
    case invalidResponse
    case decodingFailed(String)
    case cancelled
}
