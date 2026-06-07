// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraOnboarding",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraOnboarding", targets: ["BabyCameraOnboarding"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../BabyCameraAccount"),
        .package(path: "../BabyCameraFamily"),
        .package(path: "../BabyCameraBaby"),
    ],
    targets: [
        .target(
            name: "BabyCameraOnboarding",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraAccount",
                "BabyCameraFamily",
                "BabyCameraBaby",
            ]
        ),
        .testTarget(
            name: "BabyCameraOnboardingTests",
            dependencies: ["BabyCameraOnboarding", "BabyCameraNetwork"]
        ),
    ]
)
