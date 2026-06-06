// swift-tools-version: 5.10
// Monorepo SPM manifest — 本地 packages 聚合引用
import PackageDescription

let package = Package(
    name: "BabyCameraMonorepo",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Database", targets: ["Database"]),
        .library(name: "BabyCameraNetwork", targets: ["BabyCameraNetwork"]),
        .library(name: "UIKitBridge", targets: ["UIKitBridge"]),
        .library(name: "Widgets", targets: ["Widgets"]),
        .library(name: "BabyCameraPermissions", targets: ["BabyCameraPermissions"]),
        .library(name: "BabyCameraImageKit", targets: ["BabyCameraImageKit"]),
        .library(name: "BabyCameraVideoKit", targets: ["BabyCameraVideoKit"]),
        .library(name: "BabyCameraAccount", targets: ["BabyCameraAccount"]),
        .library(name: "BabyCameraEditor", targets: ["BabyCameraEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            path: "Packages/DesignSystem/Sources/DesignSystem"
        ),
        .target(
            name: "Database",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Packages/Database/Sources/Database"
        ),
        .target(
            name: "BabyCameraNetwork",
            path: "Packages/BabyCameraNetwork/Sources/BabyCameraNetwork"
        ),
        .target(
            name: "UIKitBridge",
            dependencies: ["DesignSystem"],
            path: "Packages/UIKitBridge/Sources/UIKitBridge"
        ),
        .target(
            name: "Widgets",
            path: "Packages/Widgets/Sources/Widgets"
        ),
        .target(
            name: "BabyCameraPermissions",
            path: "Packages/BabyCameraPermissions/Sources/BabyCameraPermissions"
        ),
        .target(
            name: "BabyCameraImageKit",
            path: "Packages/BabyCameraImageKit/Sources/BabyCameraImageKit"
        ),
        .target(
            name: "BabyCameraVideoKit",
            path: "Packages/BabyCameraVideoKit/Sources/BabyCameraVideoKit"
        ),
        .target(
            name: "BabyCameraAccount",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
            ],
            path: "Packages/BabyCameraAccount/Sources/BabyCameraAccount"
        ),
        .target(
            name: "BabyCameraEditor",
            path: "Packages/BabyCameraEditor/Sources/BabyCameraEditor"
        ),
    ]
)
