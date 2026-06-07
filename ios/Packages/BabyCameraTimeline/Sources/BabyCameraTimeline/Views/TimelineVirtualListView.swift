import DesignSystem
import SwiftUI

/// 虚拟列表容器：`LazyVStack` + 按需加载更多。
struct TimelineVirtualListView: View {
    let scale: TimelineScale
    let rows: [TimelineRow]
    let isLoadingMore: Bool
    @ObservedObject var thumbnailLoader: TimelineThumbnailLoader
    let onLoadMore: (Int) -> Void
    var onPhotoTap: ((TimelinePhotoItem) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.sm, pinnedViews: []) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row, index: index)
                        .onAppear {
                            onLoadMore(index)
                        }
                }

                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(DSSpacing.md)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.bottom, DSSpacing.lg)
        }
    }

    @ViewBuilder
    private func rowView(_ row: TimelineRow, index: Int) -> some View {
        switch row {
        case let .sectionHeader(_, title):
            TimelineSectionHeaderView(title: title)
        case let .photo(item):
            TimelinePhotoThumbnailView(
                item: item,
                columnCount: scale.gridColumnCount,
                thumbnailLoader: thumbnailLoader,
                onTap: onPhotoTap.map { handler in { handler(item) } }
            )
        }
    }
}

/// 网格区块：同一 section 内多列布局（月 / 年 / 全部）。
struct TimelineSectionGridView: View {
    let title: String?
    let photos: [TimelinePhotoItem]
    let columnCount: Int
    @ObservedObject var thumbnailLoader: TimelineThumbnailLoader
    var onPhotoTap: ((TimelinePhotoItem) -> Void)?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xs), count: columnCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let title {
                TimelineSectionHeaderView(title: title)
            }
            LazyVGrid(columns: columns, spacing: DSSpacing.xs) {
                ForEach(photos) { item in
                    TimelinePhotoThumbnailView(
                        item: item,
                        columnCount: columnCount,
                        thumbnailLoader: thumbnailLoader,
                        onTap: onPhotoTap.map { handler in { handler(item) } }
                    )
                }
            }
        }
    }
}
