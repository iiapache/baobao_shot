import Foundation

/// 虚拟列表数据源：维护展平行索引与分页窗口。
public struct TimelineVirtualDataSource: Sendable {
    public private(set) var allRows: [TimelineRow] = []
    public private(set) var loadedPhotoCount: Int = 0
    public private(set) var hasMore: Bool = true

    private let pageSize: Int

    public init(pageSize: Int = 60) {
        self.pageSize = pageSize
    }

    public mutating func reset(rows: [TimelineRow], loadedPhotoCount: Int, hasMore: Bool) {
        allRows = rows
        self.loadedPhotoCount = loadedPhotoCount
        self.hasMore = hasMore
    }

    public mutating func append(rows: [TimelineRow], additionalPhotoCount: Int, hasMore: Bool) {
        allRows.append(contentsOf: rows)
        loadedPhotoCount += additionalPhotoCount
        self.hasMore = hasMore
    }

    public var totalRowCount: Int { allRows.count }

    public func row(at index: Int) -> TimelineRow? {
        guard allRows.indices.contains(index) else { return nil }
        return allRows[index]
    }

    public func rows(in range: Range<Int>) -> [TimelineRow] {
        guard !allRows.isEmpty else { return [] }
        let lower = max(range.lowerBound, 0)
        let upper = min(range.upperBound, allRows.count)
        guard lower < upper else { return [] }
        return Array(allRows[lower..<upper])
    }

    /// 当滚动接近末尾时触发加载更多。
    public func shouldLoadMore(visibleIndex: Int, prefetchThreshold: Int = 12) -> Bool {
        guard hasMore else { return false }
        return visibleIndex >= totalRowCount - prefetchThreshold
    }

    public var nextPageSize: Int { pageSize }
}
