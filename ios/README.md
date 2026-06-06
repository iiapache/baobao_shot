# iOS 端工程

宝宝成长相机 iOS 客户端（iOS 16+，Swift 5.10+）。工程结构与 [design-ios.md §3](../docs/design-ios.md#3-工程结构) 对齐。

## 前置要求

- macOS 14+
- Xcode 16+（含 iOS 18 SDK）
- Command Line Tools

## 目录结构

```text
ios/
├── BabyCamera.xcodeproj          # Xcode 工程
├── BabyCamera.xcworkspace        # Workspace（含工程 + 根 Package.swift）
├── Package.swift                 # Monorepo SPM 聚合 manifest
├── Package.resolved              # SPM lockfile（首次 build 后生成）
├── BabyCamera/                   # 源码目录（与 design-ios §3.1 一致）
│   ├── App/                      # @main 入口
│   ├── Features/                 # 业务 Feature（Account / Camera / …）
│   ├── Core/                     # 跨 Feature 复用
│   ├── Data/                     # 持久化与仓储
│   ├── Network/                  # REST / WebSocket
│   ├── UIKitBridge/              # UIKit 桥接
│   ├── Widgets/                  # 小组件 Target 占位
│   └── Resources/                # Assets / 本地化 / 字体
└── Packages/                     # 本地 SPM 模块
    ├── DesignSystem/             # Core/DesignSystem 占位
    ├── Database/                 # Data/Database 占位
    ├── BabyCameraNetwork/        # Network 占位
    ├── UIKitBridge/
    └── Widgets/
```

## 打开工程

```bash
open BabyCamera.xcworkspace
```

或使用 Xcode 直接打开 `BabyCamera.xcodeproj`。

## 命令行构建

在 `ios/` 目录下执行：

```bash
# 查看构建设置（验收项）
xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera -showBuildSettings

# 模拟器构建
xcodebuild \
  -project BabyCamera.xcodeproj \
  -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# 通用 iOS 设备（无需指定模拟器）
xcodebuild \
  -project BabyCamera.xcodeproj \
  -scheme BabyCamera \
  -destination 'generic/platform=iOS' \
  build
```

## SPM 模块

| 模块 | 路径 | 说明 |
| --- | --- | --- |
| DesignSystem | `Packages/DesignSystem` | 颜色 / 字体 / 组件（T0.14） |
| Database | `Packages/Database` | GRDB + Migration（T0.16） |
| BabyCameraNetwork | `Packages/BabyCameraNetwork` | URLSession 网络层（T0.15） |
| UIKitBridge | `Packages/UIKitBridge` | 相机 / 编辑器 UIKit 桥接 |
| Widgets | `Packages/Widgets` | WidgetKit 小组件 |

根目录 `Package.swift` 提供 monorepo 视角的聚合引用，便于 CI 与 IDE 统一解析。

## 配置

| 项 | 值 |
| --- | --- |
| 最低系统 | iOS 16.0 |
| Swift | 5.10+（Strict Concurrency） |
| Bundle ID | `com.babycamera.app` |
| 显示名称 | 宝宝成长相机 |

## Fastlane

CI/CD 脚本见 [fastlane/](./fastlane/)。
