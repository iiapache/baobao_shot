// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraFamilyFeed",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraFamilyFeed", targets: ["BabyCameraFamilyFeed"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../BabyCameraBaby"),
        .package(path: "../BabyCameraWatermark"),
        .package(path: "../BabyCameraImageKit"),
        .package(path: "../BabyCameraVideoKit"),
        .package(path: "../Database"),
    ],
    targets: [
        .target(
            name: "BabyCameraFamilyFeed",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraBaby",
                "BabyCameraWatermark",
                "BabyCameraImageKit",
                "BabyCameraVideoKit",
                "Database",
            ]
        ),
        .testTarget(
            name: "BabyCameraFamilyFeedTests",
            dependencies: [
                "BabyCameraFamilyFeed",
                "BabyCameraNetwork",
                "BabyCameraWatermark",
                "BabyCameraImageKit",
                "BabyCameraVideoKit",
                "Database",
            ]
        ),
    ]
)
