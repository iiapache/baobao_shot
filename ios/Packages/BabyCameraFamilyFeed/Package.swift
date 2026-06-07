// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BabyCameraFamilyFeed",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BabyCameraFamilyFeed", targets: ["BabyCameraFamilyFeed"]),
    ],
    dependencies: [
        // WECHAT_SPM_START — 执行 scripts/enable-wechat-opensdk.sh 取消注释以链接 WechatOpenSDK
        // .package(url: "https://github.com/yanyin1986/WechatOpenSDK.git", from: "2.0.4"),
        // WECHAT_SPM_END
        .package(path: "../DesignSystem"),
        .package(path: "../BabyCameraNetwork"),
        .package(path: "../BabyCameraBaby"),
        .package(path: "../BabyCameraWatermark"),
        .package(path: "../BabyCameraImageKit"),
        .package(path: "../BabyCameraVideoKit"),
        .package(path: "../Database"),
    ],
    targets: [
        .target(
            name: "BabyCameraFamilyFeed",
            dependencies: [
                // WECHAT_PRODUCT_START
                // .product(name: "WechatOpenSDK", package: "WechatOpenSDK"),
                // WECHAT_PRODUCT_END
                "DesignSystem",
                "BabyCameraNetwork",
                "BabyCameraBaby",
                "BabyCameraWatermark",
                "BabyCameraImageKit",
                "BabyCameraVideoKit",
                "Database",
            ]
        ),
        .testTarget(
            name: "BabyCameraFamilyFeedTests",
            dependencies: [
                "BabyCameraFamilyFeed",
                "BabyCameraNetwork",
                "BabyCameraWatermark",
                "BabyCameraImageKit",
                "BabyCameraVideoKit",
                "Database",
            ]
        ),
    ]
)
