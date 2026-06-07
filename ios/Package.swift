// swift-tools-version: 5.10
// Monorepo SPM manifest — 本地 packages 聚合引用
import PackageDescription

let package = Package(
    name: "BabyCameraMonorepo",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Database", targets: ["Database"]),
        .library(name: "BabyCameraNetwork", targets: ["BabyCameraNetwork"]),
        .library(name: "UIKitBridge", targets: ["UIKitBridge"]),
        .library(name: "Widgets", targets: ["Widgets"]),
        .library(name: "BabyCameraPermissions", targets: ["BabyCameraPermissions"]),
        .library(name: "BabyCameraImageKit", targets: ["BabyCameraImageKit"]),
        .library(name: "BabyCameraVideoKit", targets: ["BabyCameraVideoKit"]),
        .library(name: "BabyCameraAccount", targets: ["BabyCameraAccount"]),
        .library(name: "BabyCameraFamily", targets: ["BabyCameraFamily"]),
        .library(name: "BabyCameraEditor", targets: ["BabyCameraEditor"]),
        .library(name: "BabyCameraBaby", targets: ["BabyCameraBaby"]),
        .library(name: "BabyCameraCamera", targets: ["BabyCameraCamera"]),
        .library(name: "BabyCameraOnboarding", targets: ["BabyCameraOnboarding"]),
        .library(name: "BabyCameraWatermark", targets: ["BabyCameraWatermark"]),
        .library(name: "BabyCameraMilestone", targets: ["BabyCameraMilestone"]),
        .library(name: "BabyCameraAIPlay", targets: ["BabyCameraAIPlay"]),
        .library(name: "BabyCameraCredit", targets: ["BabyCameraCredit"]),
        .library(name: "BabyCameraDiagnostics", targets: ["BabyCameraDiagnostics"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            path: "Packages/DesignSystem/Sources/DesignSystem"
        ),
        .target(
            name: "Database",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Packages/Database/Sources/Database"
        ),
        .target(
            name: "BabyCameraNetwork",
            path: "Packages/BabyCameraNetwork/Sources/BabyCameraNetwork"
        ),
        .target(
            name: "UIKitBridge",
            dependencies: ["DesignSystem"],
            path: "Packages/UIKitBridge/Sources/UIKitBridge"
        ),
        .target(
            name: "Widgets",
            path: "Packages/Widgets/Sources/Widgets"
        ),
        .target(
            name: "BabyCameraPermissions",
            path: "Packages/BabyCameraPermissions/Sources/BabyCameraPermissions"
        ),
        .target(
            name: "BabyCameraImageKit",
            dependencies: ["BabyCameraDiagnostics"],
            path: "Packages/BabyCameraImageKit/Sources/BabyCameraImageKit"
        ),
        .target(
            name: "BabyCameraVideoKit",
            path: "Packages/BabyCameraVideoKit/Sources/BabyCameraVideoKit"
        ),
        .target(
            name: "BabyCameraAccount",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraDiagnostics",
            ],
            path: "Packages/BabyCameraAccount/Sources/BabyCameraAccount"
        ),
        .target(
            name: "BabyCameraFamily",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraDiagnostics",
            ],
            path: "Packages/BabyCameraFamily/Sources/BabyCameraFamily"
        ),
        .target(
            name: "BabyCameraEditor",
            dependencies: [
                "BabyCameraImageKit",
                "BabyCameraDiagnostics",
            ],
            path: "Packages/BabyCameraEditor/Sources/BabyCameraEditor",
            resources: [.process("Resources")]
        ),
        .target(
            name: "BabyCameraBaby",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "Database",
            ],
            path: "Packages/BabyCameraBaby/Sources/BabyCameraBaby"
        ),
        .target(
            name: "BabyCameraCamera",
            dependencies: [
                "BabyCameraPermissions",
                "BabyCameraImageKit",
                "BabyCameraBaby",
                "BabyCameraDiagnostics",
                "Database",
            ],
            path: "Packages/BabyCameraCamera/Sources/BabyCameraCamera"
        ),
        .target(
            name: "BabyCameraOnboarding",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraAccount",
                "BabyCameraFamily",
                "BabyCameraBaby",
            ],
            path: "Packages/BabyCameraOnboarding/Sources/BabyCameraOnboarding"
        ),
        .target(
            name: "BabyCameraMilestone",
            dependencies: [
                "BabyCameraEditor",
                "Database",
            ],
            path: "Packages/BabyCameraMilestone/Sources/BabyCameraMilestone",
            resources: [.process("Resources")]
        ),
        .target(
            name: "BabyCameraWatermark",
            dependencies: [
                "BabyCameraImageKit",
                "BabyCameraCamera",
            ],
            path: "Packages/BabyCameraWatermark/Sources/BabyCameraWatermark"
        ),
        .target(
            name: "BabyCameraTimeline",
            dependencies: [
                "DesignSystem",
                "Database",
                "BabyCameraImageKit",
                "BabyCameraBaby",
            ],
            path: "Packages/BabyCameraTimeline/Sources/BabyCameraTimeline"
        ),
        .target(
            name: "BabyCameraAIPlay",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraCredit",
                "Database",
                "BabyCameraWatermark",
                "BabyCameraImageKit",
                "BabyCameraVideoKit",
            ],
            path: "Packages/BabyCameraAIPlay/Sources/BabyCameraAIPlay"
        ),
        .target(
            name: "BabyCameraCredit",
            dependencies: [
                "DesignSystem",
                "BabyCameraNetwork",
            ],
            path: "Packages/BabyCameraCredit/Sources/BabyCameraCredit"
        ),
        .testTarget(
            name: "BabyCameraAIPlayTests",
            dependencies: [
                "BabyCameraAIPlay",
                "BabyCameraNetwork",
                "BabyCameraCredit",
                "Database",
                "BabyCameraImageKit",
                "BabyCameraWatermark",
            ],
            path: "Packages/BabyCameraAIPlay/Tests/BabyCameraAIPlayTests"
        ),
        .testTarget(
            name: "BabyCameraCreditTests",
            dependencies: ["BabyCameraCredit", "BabyCameraNetwork"],
            path: "Packages/BabyCameraCredit/Tests/BabyCameraCreditTests"
        ),
        .testTarget(
            name: "BabyCameraOnboardingTests",
            dependencies: ["BabyCameraOnboarding", "BabyCameraNetwork"],
            path: "Packages/BabyCameraOnboarding/Tests/BabyCameraOnboardingTests"
        ),
        .testTarget(
            name: "BabyCameraEditorTests",
            dependencies: ["BabyCameraEditor"],
            path: "Packages/BabyCameraEditor/Tests/BabyCameraEditorTests"
        ),
        .testTarget(
            name: "BabyCameraWatermarkTests",
            dependencies: [
                "BabyCameraWatermark",
                "BabyCameraImageKit",
                "BabyCameraCamera",
            ],
            path: "Packages/BabyCameraWatermark/Tests/BabyCameraWatermarkTests"
        ),
        .testTarget(
            name: "BabyCameraMilestoneTests",
            dependencies: ["BabyCameraMilestone", "Database"],
            path: "Packages/BabyCameraMilestone/Tests/BabyCameraMilestoneTests"
        ),
        .testTarget(
            name: "BabyCameraTimelineTests",
            dependencies: ["BabyCameraTimeline", "Database"],
            path: "Packages/BabyCameraTimeline/Tests/BabyCameraTimelineTests"
        ),
        .testTarget(
            name: "WidgetsTests",
            dependencies: ["Widgets"],
            path: "Packages/Widgets/Tests/WidgetsTests"
        ),
        .target(
            name: "BabyCameraDiagnostics",
            path: "Packages/BabyCameraDiagnostics/Sources/BabyCameraDiagnostics"
        ),
        .testTarget(
            name: "BabyCameraDiagnosticsTests",
            dependencies: ["BabyCameraDiagnostics"],
            path: "Packages/BabyCameraDiagnostics/Tests/BabyCameraDiagnosticsTests"
        ),
    ]
)
