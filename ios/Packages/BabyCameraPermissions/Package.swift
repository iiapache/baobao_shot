// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraPermissions",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraPermissions", targets: ["BabyCameraPermissions"]),
    ],
    targets: [
        .target(name: "BabyCameraPermissions"),
        .testTarget(
            name: "BabyCameraPermissionsTests",
            dependencies: ["BabyCameraPermissions"]
        ),
    ]
)
