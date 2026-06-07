// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraBaby",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraBaby", targets: ["BabyCameraBaby"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../Database"),
    ],
    targets: [
        .target(
            name: "BabyCameraBaby",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "Database",
            ]
        ),
        .testTarget(
            name: "BabyCameraBabyTests",
            dependencies: ["BabyCameraBaby", "BabyCameraNetwork"]
        ),
    ]
)
