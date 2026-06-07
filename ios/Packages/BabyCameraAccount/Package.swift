// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraAccount",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraAccount", targets: ["BabyCameraAccount"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../BabyCameraDiagnostics"),
    ],
    targets: [
        .target(
            name: "BabyCameraAccount",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraDiagnostics",
            ]
        ),
        .testTarget(
            name: "BabyCameraAccountTests",
            dependencies: ["BabyCameraAccount", "BabyCameraNetwork"]
        ),
    ]
)
