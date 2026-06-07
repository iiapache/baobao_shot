import Foundation

public struct AIPlaySubmissionContext: Sendable, Equatable {
    public let inputObjectKey: String
    public let familyId: String
    public let aspectRatio: String?

    public init(
        inputObjectKey: String,
        familyId: String,
        aspectRatio: String? = "1:1"
    ) {
        self.inputObjectKey = inputObjectKey
        self.familyId = familyId
        self.aspectRatio = aspectRatio
    }
}
