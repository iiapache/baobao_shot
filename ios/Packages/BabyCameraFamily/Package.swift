// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraFamily",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraFamily", targets: ["BabyCameraFamily"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../BabyCameraDiagnostics"),
    ],
    targets: [
        .target(
            name: "BabyCameraFamily",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraDiagnostics",
            ]
        ),
        .testTarget(
            name: "BabyCameraFamilyTests",
            dependencies: ["BabyCameraFamily", "BabyCameraNetwork"]
        ),
    ]
)
