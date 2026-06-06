// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "UIKitBridge",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "UIKitBridge", targets: ["UIKitBridge"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "UIKitBridge",
            dependencies: ["DesignSystem"]
        ),
    ]
)
