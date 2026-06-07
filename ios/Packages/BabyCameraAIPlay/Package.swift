// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraAIPlay",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraAIPlay", targets: ["BabyCameraAIPlay"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../BabyCameraCredit"),
        .package(path: "../Database"),
        .package(path: "../BabyCameraWatermark"),
        .package(path: "../BabyCameraImageKit"),
        .package(path: "../BabyCameraVideoKit"),
    ],
    targets: [
        .target(
            name: "BabyCameraAIPlay",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraCredit",
                "Database",
                "BabyCameraWatermark",
                "BabyCameraImageKit",
                "BabyCameraVideoKit",
            ]
        ),
        .testTarget(
            name: "BabyCameraAIPlayTests",
            dependencies: [
                "BabyCameraAIPlay",
                "BabyCameraNetwork",
                "BabyCameraCredit",
                "Database",
                "BabyCameraImageKit",
                "BabyCameraWatermark",
            ]
        ),
    ]
)
