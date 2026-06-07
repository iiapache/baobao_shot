// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraWatermark",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraWatermark", targets: ["BabyCameraWatermark"]),
    ],
    dependencies: [
        .package(path: "../BabyCameraImageKit"),
        .package(path: "../BabyCameraCamera"),
    ],
    targets: [
        .target(
            name: "BabyCameraWatermark",
            dependencies: [
                "BabyCameraImageKit",
                "BabyCameraCamera",
            ]
        ),
        .testTarget(
            name: "BabyCameraWatermarkTests",
            dependencies: [
                "BabyCameraWatermark",
                "BabyCameraImageKit",
                "BabyCameraCamera",
            ]
        ),
    ]
)
