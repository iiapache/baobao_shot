import BabyCameraBaby
import DesignSystem
import SwiftUI

/// 成长时间线主视图（日 / 月 / 年 / 全部）。
///
/// 命名 `GrowthTimelineView` 以避免与 SwiftUI 内置 `TimelineView` 冲突。
public struct GrowthTimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @StateObject private var thumbnailLoader: TimelineThumbnailLoader
    private let onPhotoTap: ((TimelinePhotoItem) -> Void)?

    public init(
        viewModel: TimelineViewModel,
        thumbnailLoader: TimelineThumbnailLoader = TimelineThumbnailLoader(),
        onPhotoTap: ((TimelinePhotoItem) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _thumbnailLoader = StateObject(wrappedValue: thumbnailLoader)
        self.onPhotoTap = onPhotoTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            scalePicker
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)

            content
        }
        .background(DSColors.background)
        .accessibilityIdentifier("growthTimelineView")
        .task {
            await viewModel.reload()
        }
        .onChange(of: viewModel.scale) { _ in
            thumbnailLoader.cancelAll()
        }
    }

    private var scalePicker: some View {
        Picker("视图", selection: Binding(
            get: { viewModel.scale },
            set: { viewModel.setScale($0) }
        )) {
            ForEach(TimelineScale.allCases) { scale in
                Text(scale.title).tag(scale)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("timelineScalePicker")
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.rows.isEmpty {
            DSLoadingView(message: "加载时间线…", style: .fullScreen)
        } else if let error = viewModel.errorMessage, viewModel.rows.isEmpty {
            DSEmptyState(
                systemImage: "exclamationmark.triangle",
                title: "无法加载",
                message: error,
                actionTitle: "重试"
            ) {
                Task { await viewModel.reload() }
            }
        } else if viewModel.scale == .map {
            mapContent
        } else if viewModel.rows.isEmpty {
            DSEmptyState(
                systemImage: "photo.on.rectangle.angled",
                title: "还没有照片",
                message: "拍第一张宝宝照片，开始记录成长瞬间吧。"
            )
        } else {
            timelineBody
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        if viewModel.geoPhotoCount == 0 {
            DSEmptyState(
                systemImage: "map",
                title: "暂无地理位置",
                message: "开启位置权限并拍摄照片后，足迹将显示在地图上。"
            )
        } else {
            TimelineMapView(
                clusters: viewModel.mapClusters,
                regionStyle: $viewModel.mapRegionStyle
            )
        }
    }

    @ViewBuilder
    private var timelineBody: some View {
        switch viewModel.scale {
        case .map:
            mapContent
        case .day:
            TimelineVirtualListView(
                scale: viewModel.scale,
                rows: viewModel.rows,
                isLoadingMore: viewModel.isLoadingMore,
                thumbnailLoader: thumbnailLoader,
                onLoadMore: { index in
                    Task { await viewModel.loadMoreIfNeeded(visibleRowIndex: index) }
                },
                onPhotoTap: onPhotoTap
            )
        case .month, .year, .all:
            sectionGridScrollView
        }
    }

    private var sectionGridScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.md) {
                ForEach(viewModel.sections) { section in
                    TimelineSectionGridView(
                        title: viewModel.scale == .all ? nil : section.title,
                        photos: section.photos,
                        columnCount: viewModel.scale.gridColumnCount,
                        thumbnailLoader: thumbnailLoader,
                        onPhotoTap: onPhotoTap
                    )
                    .onAppear {
                        let lastIndex = viewModel.rows.count - 1
                        Task { await viewModel.loadMoreIfNeeded(visibleRowIndex: lastIndex) }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(DSSpacing.md)
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.bottom, DSSpacing.lg)
        }
    }
}

#Preview {
    let store = CurrentBabyEnvironment(restorePersistedSelection: false)
    store.select(babyId: "baby_1")
    let source = InMemoryTimelinePhotoSource(photos: [])
    let vm = TimelineViewModel(photoSource: source, currentBabyStore: store)
    return GrowthTimelineView(viewModel: vm)
}
