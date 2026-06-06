// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraEditor",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraEditor", targets: ["BabyCameraEditor"]),
    ],
    targets: [
        .target(name: "BabyCameraEditor"),
        .testTarget(
            name: "BabyCameraEditorTests",
            dependencies: ["BabyCameraEditor"]
        ),
    ]
)
