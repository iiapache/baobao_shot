import BabyCameraBaby
import Database
import XCTest
@testable import BabyCameraTimeline

final class TimelineMapClusteringTests: XCTestCase {
    func testPhotosWithGPSFiltersMissingCoordinates() {
        let photos = [
            makeItem(id: "with-gps", lat: 31.2, lng: 121.5),
            makeItem(id: "no-gps"),
            makeItem(id: "partial-lat", lat: 39.9, lng: nil),
            makeItem(id: "partial-lng", lat: nil, lng: 116.4),
        ]

        let filtered = TimelineMapClustering.photosWithGPS(photos)

        XCTAssertEqual(filtered.map(\.id), ["with-gps"])
    }

    func testClusterExcludesPhotosWithoutGPS() {
        let photos = [
            makeItem(id: "a", lat: 31.2304, lng: 121.4737),
            makeItem(id: "b"),
            makeItem(id: "c", lat: 31.2305, lng: 121.4738),
        ]

        let clusters = TimelineMapClustering.cluster(photos: photos, radiusMeters: 50)

        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].count, 2)
        XCTAssertEqual(Set(clusters[0].photos.map(\.id)), ["a", "c"])
    }

    func testNearbyPhotosMergeIntoSingleCluster() {
        let photos = [
            makeItem(id: "p1", lat: 39.9042, lng: 116.4074),
            makeItem(id: "p2", lat: 39.90425, lng: 116.40745),
            makeItem(id: "p3", lat: 39.9043, lng: 116.4075),
        ]

        let clusters = TimelineMapClustering.cluster(photos: photos, radiusMeters: 50)

        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].count, 3)
        XCTAssertTrue(clusters[0].isCluster)
    }

    func testDistantPhotosStaySeparate() {
        let photos = [
            makeItem(id: "shanghai", lat: 31.2304, lng: 121.4737),
            makeItem(id: "beijing", lat: 39.9042, lng: 116.4074),
        ]

        let clusters = TimelineMapClustering.cluster(photos: photos, radiusMeters: 50)

        XCTAssertEqual(clusters.count, 2)
        XCTAssertFalse(clusters[0].isCluster)
        XCTAssertFalse(clusters[1].isCluster)
    }

    func testEmptyInputReturnsNoClusters() {
        XCTAssertTrue(TimelineMapClustering.cluster(photos: []).isEmpty)
        XCTAssertTrue(
            TimelineMapClustering.cluster(photos: [makeItem(id: "no-gps")]).isEmpty
        )
    }

    func testClusterCentroidAveragesCoordinates() {
        let photos = [
            makeItem(id: "p1", lat: 40.0, lng: 116.0),
            makeItem(id: "p2", lat: 40.0004, lng: 116.0004),
        ]

        let clusters = TimelineMapClustering.cluster(photos: photos, radiusMeters: 50)

        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].latitude, 40.0002, accuracy: 0.0001)
        XCTAssertEqual(clusters[0].longitude, 116.0002, accuracy: 0.0001)
    }

    func testMapRegionStylePreferredForAppRegion() {
        XCTAssertEqual(TimelineMapRegionStyle.preferred(forAppRegion: "cn"), .china)
        XCTAssertEqual(TimelineMapRegionStyle.preferred(forAppRegion: "CN"), .china)
        XCTAssertEqual(TimelineMapRegionStyle.preferred(forAppRegion: "os"), .international)
        XCTAssertEqual(TimelineMapRegionStyle.preferred(forAppRegion: "OS"), .international)
    }

    func testRegionFittingFallsBackWhenNoClusters() {
        let china = TimelineMapRegionConfiguration.regionFitting(
            clusters: [],
            style: .china
        )
        let world = TimelineMapRegionConfiguration.regionFitting(
            clusters: [],
            style: .international
        )

        XCTAssertEqual(china.center.latitude, 35.8617, accuracy: 0.01)
        XCTAssertEqual(world.span.longitudeDelta, 160, accuracy: 0.01)
    }

    // MARK: - Helpers

    private func makeItem(
        id: String,
        lat: Double? = nil,
        lng: Double? = nil
    ) -> TimelinePhotoItem {
        TimelinePhotoItem(
            id: id,
            takenAt: Int64(id.hashValue),
            filePath: "/tmp/\(id).heic",
            latitude: lat,
            longitude: lng
        )
    }
}

final class TimelineMapViewModelTests: XCTestCase {
    @MainActor
    func testMapScaleBuildsClustersFromGPSPhotos() async {
        let store = CurrentBabyEnvironment(restorePersistedSelection: false)
        store.select(babyId: "baby_1")

        let photos = [
            PhotoRecord(
                id: "geo1",
                babyIds: ["baby_1"],
                userId: "u1",
                takenAt: 100,
                lat: 31.23,
                lng: 121.47,
                sha256: "a",
                filePath: "/geo1.heic"
            ),
            PhotoRecord(
                id: "nogeo",
                babyIds: ["baby_1"],
                userId: "u1",
                takenAt: 90,
                sha256: "b",
                filePath: "/nogeo.heic"
            ),
        ]

        let vm = TimelineViewModel(
            photoSource: InMemoryTimelinePhotoSource(photos: photos),
            currentBabyStore: store
        )
        await vm.reload()
        vm.setScale(.map)

        XCTAssertEqual(vm.geoPhotoCount, 1)
        XCTAssertEqual(vm.mapClusters.count, 1)
        XCTAssertTrue(vm.rows.isEmpty)
    }
}
