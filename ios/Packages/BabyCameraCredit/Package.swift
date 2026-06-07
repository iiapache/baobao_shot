// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraCredit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraCredit", targets: ["BabyCameraCredit"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
    ],
    targets: [
        .target(
            name: "BabyCameraCredit",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
            ]
        ),
        .testTarget(
            name: "BabyCameraCreditTests",
            dependencies: ["BabyCameraCredit", "BabyCameraNetwork"]
        ),
    ]
)
