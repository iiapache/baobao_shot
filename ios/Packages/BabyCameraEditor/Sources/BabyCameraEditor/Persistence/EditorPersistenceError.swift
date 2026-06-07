import Foundation

public enum EditorPersistenceError: Error, Equatable, Sendable {
    case photoIdEmpty
    case stepsNotFound(String)
    case writeFailed
    case decodeFailed
}
