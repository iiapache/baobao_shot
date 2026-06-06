// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraNetwork",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraNetwork", targets: ["BabyCameraNetwork"]),
    ],
    targets: [
        .target(name: "BabyCameraNetwork"),
        .testTarget(
            name: "BabyCameraNetworkTests",
            dependencies: ["BabyCameraNetwork"]
        ),
    ]
)
