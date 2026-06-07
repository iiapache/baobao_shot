import Foundation

public enum BabyGender: String, CaseIterable, Sendable, Codable, Identifiable {
    case male
    case female
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .male: "男孩"
        case .female: "女孩"
        case .unknown: "暂不填写"
        }
    }

    public var apiValue: String {
        switch self {
        case .male: "male"
        case .female: "female"
        case .unknown: ""
        }
    }

    public init(apiValue: String?) {
        switch apiValue?.lowercased() {
        case "male", "boy":
            self = .male
        case "female", "girl":
            self = .female
        default:
            self = .unknown
        }
    }
}
