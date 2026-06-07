// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraNotification",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraNotification", targets: ["BabyCameraNotification"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../BabyCameraMilestone"),
    ],
    targets: [
        .target(
            name: "BabyCameraNotification",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraMilestone",
            ]
        ),
        .testTarget(
            name: "BabyCameraNotificationTests",
            dependencies: [
                "BabyCameraNotification",
                "BabyCameraNetwork",
                "BabyCameraMilestone",
            ]
        ),
    ]
)
