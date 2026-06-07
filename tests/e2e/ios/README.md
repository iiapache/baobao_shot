# T2.22 P2 端到端 XCUITest

> 任务：**T2.22** · 依赖 T2.15 EditorRenderer、T2.17 Timeline

## 覆盖范围

| 步骤 | 实现 | accessibilityIdentifier |
| --- | --- | --- |
| Mock 拍照 | `MockCameraView`，无需相机/相册权限 | `mockCaptureButton` |
| 编辑（滤镜） | `PhotoEditorFlowView` + `EditorExportService` | `filterPicker`, `applyFilterButton` |
| 保存 | 本地 JPG + `EditStepsPersistence` | `savePhotoButton` |
| Timeline 显示 | `GrowthTimelineView` + `MutableTimelinePhotoSource` | `growthTimelineView`, `timelinePhoto-{id}` |
| 重新编辑 | 点击 Timeline 缩略图恢复步骤 | `finishReEditButton` |
| 离线 stub | 启动参数 `-OfflineMode` | `offlineStatusLabel` |

## 用例清单

| 文件 | 用例 | 说明 |
| --- | --- | --- |
| `P2CaptureEditTimelineE2ETests.swift` | `testCaptureEditSaveTimelineReeditFiveTimes` | **5 次完整回归** |
| `P2CaptureEditTimelineE2ETests.swift` | `testTimelineShowsSavedPhotosAfterEachSave` | 单次保存后 Timeline 可见 |
| `P2OfflineStubTests.swift` | `testOfflineModeFullCycleStub` | 离线 1 轮完整循环 |
| `P2OfflineStubTests.swift` | `testOfflineModeTimelineAccessibleWithoutNetwork` | 离线直接打开 Timeline |

## 启动参数

App 在以下 launch arguments 下进入 P2 E2E harness（绕过登录/onboarding）：

```text
-UITesting          # 标记 UI 测试环境
-P2E2E              # 进入 P2E2ERootView
-OfflineMode        # 可选，启用离线 stub（无网络依赖）
```

## 运行步骤

### 前置

- macOS 14+、Xcode 16+
- iOS 16+ 模拟器（推荐 iPhone 16）

### Xcode GUI

1. `open ios/BabyCamera.xcworkspace`
2. Scheme 选 **BabyCamera**
3. `Product → Test`（⌘U），或 Test Navigator 中单独运行 `BabyCameraUITests`

### 命令行

在 `ios/` 目录：

```bash
# 构建 App + UITest
xcodebuild \
  -project BabyCamera.xcodeproj \
  -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build-for-testing

# 运行全部 P2 E2E 用例
xcodebuild \
  -project BabyCamera.xcodeproj \
  -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test \
  -only-testing:BabyCameraUITests

# 仅 5 次回归主用例
xcodebuild \
  -project BabyCamera.xcodeproj \
  -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test \
  -only-testing:BabyCameraUITests/P2CaptureEditTimelineE2ETests/testCaptureEditSaveTimelineReeditFiveTimes

# 仅离线 stub
xcodebuild \
  -project BabyCamera.xcodeproj \
  -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test \
  -only-testing:BabyCameraUITests/P2OfflineStubTests
```

### 手动验证 P2 harness（不跑 XCUITest）

Edit Scheme → Run → Arguments Passed On Launch：

```text
-P2E2E
-OfflineMode
```

Run 后应直接进入 mock 相机界面。

## 目录结构

```text
ios/
├── BabyCamera/Features/P2E2E/     # App 内 E2E harness
│   ├── UITestLaunchConfiguration.swift
│   ├── P2E2EFlowStore.swift
│   ├── MockCameraView.swift
│   ├── PhotoEditorFlowView.swift
│   └── P2E2ERootView.swift
└── BabyCameraUITests/            # XCUITest target
    ├── P2CaptureEditTimelineE2ETests.swift
    ├── P2OfflineStubTests.swift
    └── XCUITestHelpers.swift

tests/e2e/ios/README.md           # 本文件
```

## 验收对照（T2.22）

| 验收项 | 状态 |
| --- | --- |
| XCUITest 用例可编译 | ✅ 工程含 `BabyCameraUITests` target |
| 拍照 mock（无真机相机） | ✅ `MockCameraView` |
| 编辑滤镜 → 保存 | ✅ `EditorExportService` + 步骤持久化 |
| Timeline 显示 | ✅ `GrowthTimelineView` |
| 重新编辑循环 | ✅ 5 次 `testCaptureEditSaveTimelineReeditFiveTimes` |
| 离线全过程 stub | ✅ `P2OfflineStubTests` + `-OfflineMode` |
| 运行文档 | ✅ 本文 |

## 已知限制

- 当前 harness 为 **P2 专用测试入口**，非生产主流程；主 App 仍走 Account/Onboarding。
- Metal `EditorRenderer` 在部分 CI/macOS 无 GPU 环境可能失败；需在 macOS + 模拟器本地验证。
- P2 完成判定要求用例 **3 次稳定通过**；建议在 PR 前本地连跑 3 次 `testCaptureEditSaveTimelineReeditFiveTimes`。

## 相关任务

- T2.15：EditorRenderer / EditStepsPersistence
- T2.17：GrowthTimelineView
- T2.22：本目录
