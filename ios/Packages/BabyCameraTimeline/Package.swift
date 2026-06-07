// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraTimeline",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraTimeline", targets: ["BabyCameraTimeline"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../Database"),
        .package(path: "../BabyCameraImageKit"),
        .package(path: "../BabyCameraBaby"),
    ],
    targets: [
        .target(
            name: "BabyCameraTimeline",
            dependencies: [
                "DesignSystem",
                "Database",
                "BabyCameraImageKit",
                "BabyCameraBaby",
            ]
        ),
        .testTarget(
            name: "BabyCameraTimelineTests",
            dependencies: ["BabyCameraTimeline", "Database"]
        ),
    ]
)
