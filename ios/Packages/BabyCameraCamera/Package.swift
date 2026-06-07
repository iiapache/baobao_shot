// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraCamera",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraCamera", targets: ["BabyCameraCamera"]),
    ],
    dependencies: [
        .package(path: "../BabyCameraPermissions"),
        .package(path: "../BabyCameraImageKit"),
        .package(path: "../BabyCameraBaby"),
        .package(path: "../BabyCameraDiagnostics"),
        .package(path: "../Database"),
    ],
    targets: [
        .target(
            name: "BabyCameraCamera",
            dependencies: [
                "BabyCameraPermissions",
                "BabyCameraImageKit",
                "BabyCameraBaby",
                "BabyCameraDiagnostics",
                "Database",
            ]
        ),
        .testTarget(
            name: "BabyCameraCameraTests",
            dependencies: [
                "BabyCameraCamera",
                "BabyCameraImageKit",
                "BabyCameraBaby",
                "Database",
            ]
        ),
    ]
)
