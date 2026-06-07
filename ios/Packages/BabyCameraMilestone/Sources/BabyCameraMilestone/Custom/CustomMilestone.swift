import Foundation

public struct CustomMilestone: Identifiable, Sendable, Equatable {
    public var id: String
    public var babyId: String
    public var name: String
    public var date: Date
    public var reminded: Bool

    public init(
        id: String,
        babyId: String,
        name: String,
        date: Date,
        reminded: Bool = false
    ) {
        self.id = id
        self.babyId = babyId
        self.name = name
        self.date = date
        self.reminded = reminded
    }
}
