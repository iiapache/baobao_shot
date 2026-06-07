import BabyCameraBaby
import Database
import Foundation

@MainActor
public final class TimelineViewModel: ObservableObject {
    @Published public private(set) var scale: TimelineScale = .day
    @Published public private(set) var rows: [TimelineRow] = []
    @Published public private(set) var sections: [TimelineSection] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var hasMore = true
    @Published public var mapRegionStyle: TimelineMapRegionStyle

    public private(set) var virtualDataSource = TimelineVirtualDataSource()

    private let photoSource: any TimelinePhotoSource
    private let currentBabyStore: CurrentBabyEnvironment
    private var loadedPhotos: [PhotoRecord] = []
    private var oldestLoadedTakenAt: Int64?

    public init(
        photoSource: any TimelinePhotoSource,
        currentBabyStore: CurrentBabyEnvironment,
        initialScale: TimelineScale = .day,
        initialMapRegionStyle: TimelineMapRegionStyle = .china
    ) {
        self.photoSource = photoSource
        self.currentBabyStore = currentBabyStore
        self.scale = initialScale
        self.mapRegionStyle = initialMapRegionStyle
    }

    /// 含 GPS 的照片数量。
    public var geoPhotoCount: Int {
        loadedPhotos.filter { $0.lat != nil && $0.lng != nil }.count
    }

    /// 地图 POI 聚合结果。
    public var mapClusters: [TimelineMapCluster] {
        let items = loadedPhotos.map(TimelinePhotoItem.init(photo:))
        return TimelineMapClustering.cluster(photos: items)
    }

    public func setScale(_ newScale: TimelineScale) {
        guard scale != newScale else { return }
        scale = newScale
        rebuildRows()
    }

    public func reload() async {
        guard let babyId = currentBabyStore.currentBabyId else {
            clearState()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let pageSize = virtualDataSource.nextPageSize
            let batch = try await photoSource.fetchPhotos(
                babyId: babyId,
                before: nil,
                limit: pageSize
            )
            loadedPhotos = batch
            oldestLoadedTakenAt = batch.last?.takenAt
            hasMore = batch.count >= pageSize
            rebuildRows()
        } catch {
            errorMessage = "加载失败，请稍后重试"
        }
    }

    public func loadMoreIfNeeded(visibleRowIndex: Int) async {
        guard virtualDataSource.shouldLoadMore(visibleIndex: visibleRowIndex),
              !isLoadingMore,
              hasMore,
              let babyId = currentBabyStore.currentBabyId,
              let cursor = oldestLoadedTakenAt
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let pageSize = virtualDataSource.nextPageSize
            let batch = try await photoSource.fetchPhotos(
                babyId: babyId,
                before: cursor,
                limit: pageSize
            )
            guard !batch.isEmpty else {
                hasMore = false
                virtualDataSource.reset(
                    rows: rows,
                    loadedPhotoCount: loadedPhotos.count,
                    hasMore: false
                )
                return
            }

            loadedPhotos.append(contentsOf: batch)
            oldestLoadedTakenAt = batch.last?.takenAt
            hasMore = batch.count >= pageSize
            rebuildRows()
        } catch {
            errorMessage = "加载更多失败"
        }
    }

    // MARK: - Private

    private func clearState() {
        loadedPhotos = []
        oldestLoadedTakenAt = nil
        rows = []
        sections = []
        hasMore = false
        virtualDataSource.reset(rows: [], loadedPhotoCount: 0, hasMore: false)
    }

    private func rebuildRows() {
        guard scale != .map else {
            sections = []
            rows = []
            virtualDataSource.reset(
                rows: [],
                loadedPhotoCount: loadedPhotos.count,
                hasMore: hasMore
            )
            return
        }

        sections = TimelineGrouping.group(photos: loadedPhotos, scale: scale)
        let newRows = TimelineGrouping.makeRows(photos: loadedPhotos, scale: scale)
        rows = newRows
        virtualDataSource.reset(
            rows: newRows,
            loadedPhotoCount: loadedPhotos.count,
            hasMore: hasMore
        )
    }
}
