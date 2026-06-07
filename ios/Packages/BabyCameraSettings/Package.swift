// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraSettings",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraSettings", targets: ["BabyCameraSettings"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../BabyCameraPermissions"),
        .package(path: "../BabyCameraAccount"),
        .package(path: "../BabyCameraFamily"),
        .package(path: "../BabyCameraNotification"),
        .package(path: "../BabyCameraOnboarding"),
        .package(path: "../Database"),
        .package(path: "../BabyCameraImageKit"),
        .package(path: "../BabyCameraBackup"),
    ],
    targets: [
        .target(
            name: "BabyCameraSettings",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraPermissions",
                "BabyCameraAccount",
                "BabyCameraFamily",
                "BabyCameraNotification",
                "BabyCameraOnboarding",
                "Database",
                "BabyCameraImageKit",
                "BabyCameraBackup",
            ]
        ),
        .testTarget(
            name: "BabyCameraSettingsTests",
            dependencies: [
                "BabyCameraSettings",
                "BabyCameraNetwork",
                "BabyCameraPermissions",
                "BabyCameraAccount",
                "BabyCameraFamily",
                "BabyCameraNotification",
                "Database",
                "BabyCameraImageKit",
                "BabyCameraBackup",
            ]
        ),
    ]
)
