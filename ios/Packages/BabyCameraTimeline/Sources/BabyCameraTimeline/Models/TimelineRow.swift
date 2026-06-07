import Foundation

/// 虚拟列表行：分组标题或照片 cell。
public enum TimelineRow: Equatable, Identifiable, Sendable {
    case sectionHeader(id: String, title: String)
    case photo(TimelinePhotoItem)

    public var id: String {
        switch self {
        case let .sectionHeader(id, _):
            return "header-\(id)"
        case let .photo(item):
            return "photo-\(item.id)"
        }
    }

    public var isPhoto: Bool {
        if case .photo = self { return true }
        return false
    }
}

extension TimelineRow {
    /// 将分组结果展平为虚拟列表行序列。
    public static func flatten(sections: [TimelineSection], includeHeaders: Bool) -> [TimelineRow] {
        sections.flatMap { section -> [TimelineRow] in
            var rows: [TimelineRow] = []
            if includeHeaders {
                rows.append(.sectionHeader(id: section.id, title: section.title))
            }
            rows.append(contentsOf: section.photos.map { .photo($0) })
            return rows
        }
    }
}
