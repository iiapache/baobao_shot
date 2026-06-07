// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Widgets",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Widgets", targets: ["Widgets"]),
    ],
    targets: [
        .target(name: "Widgets"),
        .testTarget(
            name: "WidgetsTests",
            dependencies: ["Widgets"]
        ),
    ]
)
