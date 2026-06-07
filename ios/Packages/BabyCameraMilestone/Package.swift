// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraMilestone",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraMilestone", targets: ["BabyCameraMilestone"]),
    ],
    dependencies: [
        .package(path: "../BabyCameraEditor"),
        .package(path: "../Database"),
    ],
    targets: [
        .target(
            name: "BabyCameraMilestone",
            dependencies: [
                "BabyCameraEditor",
                "Database",
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "BabyCameraMilestoneTests",
            dependencies: ["BabyCameraMilestone", "Database"]
        ),
    ]
)
