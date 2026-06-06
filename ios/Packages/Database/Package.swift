// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Database",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Database", targets: ["Database"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "Database",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "DatabaseTests",
            dependencies: ["Database"]
        ),
    ]
)
