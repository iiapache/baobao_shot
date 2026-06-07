// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraEditor",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraEditor", targets: ["BabyCameraEditor"]),
    ],
    dependencies: [
        .package(path: "../BabyCameraImageKit"),
        .package(path: "../BabyCameraDiagnostics"),
    ],
    targets: [
        .target(
            name: "BabyCameraEditor",
            dependencies: [
                "BabyCameraImageKit",
                "BabyCameraDiagnostics",
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "BabyCameraEditorTests",
            dependencies: ["BabyCameraEditor"]
        ),
    ]
)
