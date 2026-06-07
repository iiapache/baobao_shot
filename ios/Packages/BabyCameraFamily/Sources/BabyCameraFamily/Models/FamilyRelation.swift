import Foundation

/// 加入家庭时的关系称谓 — API 传 rawValue
public enum FamilyRelation: String, CaseIterable, Sendable, Identifiable {
    case mom
    case dad
    case grandma
    case grandpa
    case maternalGrandma = "maternal_grandma"
    case maternalGrandpa = "maternal_grandpa"
    case aunt
    case uncle
    case nanny
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mom: "妈妈"
        case .dad: "爸爸"
        case .grandma: "奶奶"
        case .grandpa: "爷爷"
        case .maternalGrandma: "外婆"
        case .maternalGrandpa: "外公"
        case .aunt: "阿姨/姑姑"
        case .uncle: "叔叔/舅舅"
        case .nanny: "保姆/育儿嫂"
        case .other: "其他"
        }
    }
}
