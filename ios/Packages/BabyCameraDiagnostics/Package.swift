// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraDiagnostics",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraDiagnostics", targets: ["BabyCameraDiagnostics"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BabyCameraDiagnostics"
        ),
        .testTarget(
            name: "BabyCameraDiagnosticsTests",
            dependencies: ["BabyCameraDiagnostics"]
        ),
    ]
)
