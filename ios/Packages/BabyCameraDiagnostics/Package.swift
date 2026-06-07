// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraDiagnostics",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraDiagnostics", targets: ["BabyCameraDiagnostics"]),
    ],
    dependencies: [
        // SENTRY_SPM_START — 执行 scripts/enable-crash-sdks.sh 取消注释以链接 sentry-cocoa
        // .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.36.0"),
        // SENTRY_SPM_END
    ],
    targets: [
        .target(
            name: "BabyCameraDiagnostics",
            dependencies: [
                // SENTRY_PRODUCT_START
                // .product(name: "Sentry", package: "sentry-cocoa"),
                // SENTRY_PRODUCT_END
            ]
        ),
        .testTarget(
            name: "BabyCameraDiagnosticsTests",
            dependencies: ["BabyCameraDiagnostics"]
        ),
    ]
)
