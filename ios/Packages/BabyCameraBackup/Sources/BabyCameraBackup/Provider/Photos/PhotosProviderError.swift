import Foundation

public enum PhotosProviderError: Error, Equatable, Sendable {
    case authorizationDenied
    case authorizationRestricted
    case fileNotFound(path: String)
    case writeFailed(reason: String)
}
