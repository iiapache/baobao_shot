import Foundation

public enum BaiduPanProviderError: Error, Sendable, Equatable {
    case notAuthorized
    case authorizationFailed(String)
    case localFileNotFound(path: String)
    case quotaUnavailable
    case uploadFailed(String)
    case openAPI(code: Int, message: String)
}
