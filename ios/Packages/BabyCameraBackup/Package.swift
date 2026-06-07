// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraBackup",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraBackup", targets: ["BabyCameraBackup"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BabyCameraBackup",
            dependencies: []
        ),
        .testTarget(
            name: "BabyCameraBackupTests",
            dependencies: ["BabyCameraBackup"]
        ),
    ]
)
