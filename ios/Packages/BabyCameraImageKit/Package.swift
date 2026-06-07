// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraImageKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraImageKit", targets: ["BabyCameraImageKit"]),
    ],
    dependencies: [
        .package(path: "../BabyCameraDiagnostics"),
    ],
    targets: [
        .target(
            name: "BabyCameraImageKit",
            dependencies: ["BabyCameraDiagnostics"]
        ),
        .testTarget(
            name: "BabyCameraImageKitTests",
            dependencies: ["BabyCameraImageKit"]
        ),
    ]
)
