// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraImageKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraImageKit", targets: ["BabyCameraImageKit"]),
    ],
    targets: [
        .target(name: "BabyCameraImageKit"),
        .testTarget(
            name: "BabyCameraImageKitTests",
            dependencies: ["BabyCameraImageKit"]
        ),
    ]
)
