// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraVideoKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraVideoKit", targets: ["BabyCameraVideoKit"]),
    ],
    targets: [
        .target(name: "BabyCameraVideoKit"),
        .testTarget(
            name: "BabyCameraVideoKitTests",
            dependencies: ["BabyCameraVideoKit"]
        ),
    ]
)
