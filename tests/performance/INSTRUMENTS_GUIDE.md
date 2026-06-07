# Xcode Instruments 性能测量指南 — UX-04

> 相机冷启动 ≤ **800 ms** · 编辑器打开 ≤ **500 ms**  
> 对齐 [design-ios.md](../../docs/design-ios.md) §14 · [device-matrix.md](./device-matrix.md)

## 前置条件

| 项 | 要求 |
| --- | --- |
| 设备 | iPhone 12（必测）+ iPhone 16（推荐） |
| 构建 | **Release** 或 **Profile**（更接近用户环境） |
| 权限 | 相机、相册已授权 |
| 数据 | 至少 1 个宝宝档案；Timeline 有 1 张可编辑照片 |
| 网络 | 弱网 / 离线不影响本项（纯端侧） |

## 1. 相机冷启动（≤ 800 ms）

### 定义

- **起点**：`CameraViewController` 授权通过后调用 `session.startRunning()`（代码内 `startupTimestamp`）
- **终点**：首帧预览回调 `handleFirstPreviewFrame`（`onFirstPreviewFrame`）
- **用户路径**：杀进程 → 冷启动 App → 进入相机 Tab → 看到实时预览

### Instruments 步骤

1. Xcode → **Product → Profile**（⌘I），选择 **Time Profiler**。
2. 勾选 **Record Waiting Threads**；Target 选真机 + BabyCamera。
3. 点击 Record，在设备上：**杀 App → 重新打开 → 切到相机 Tab → 预览出现**。
4. Stop 录制。
5. 在 Call Tree 中搜索：
   - `CameraViewController`
   - `startRunning`
   - `handleFirstPreviewFrame`
6. 用 **Points of Interest** 或手动对照 Console 中 `[Performance] camera_cold_start` 日志的 `elapsed=` 值。

### 交叉验证（推荐）

Debug 构建 Run 到真机，Xcode Console 过滤 `[Performance]`：

```text
[Performance] camera_cold_start source=camera_tab elapsed=720ms budget=800ms PASS
```

埋点字段：`camera_open` · `elapsedMs`

### 采样建议

| 场景 | 次数 |
| --- | --- |
| 冷启动后首次进相机 Tab | 5 |
| Tab 切换返回相机 | 3 |
| 低电量模式 | 1（扩展） |

记录 P50 / P95 / Max，填入 [PERFORMANCE_REPORT.md](./PERFORMANCE_REPORT.md)。

---

## 2. 编辑器打开（≤ 500 ms）

### 定义

- **起点**：`MainTabEditorFlowStore.presentEditor(photoId:isReEdit:)` 调用
- **终点**：`activeSession` 赋值完成（编辑器 Sheet / Navigation 呈现）
- **用户路径**：拍照完成 → 自动/手动进入编辑；或 Timeline → 重新编辑

### Instruments 步骤

1. Profile → **Time Profiler**（或 **App Launch** 不适用此项）。
2. Record 后执行：**拍照 → 进入编辑器**（或 Timeline 点重新编辑）。
3. Call Tree 搜索：
   - `presentEditor`
   - `prepareEditor`
   - `EditorState.restore` / `CIImage(contentsOf:)`
4. 对照 Console：

```text
[Performance] editor_open source=camera elapsed=420ms budget=500ms PASS
```

埋点字段：`editor_open` · `source` · `elapsedMs`

### 采样建议

| 来源 (`source`) | 次数 |
| --- | --- |
| `camera`（拍照后编辑） | 5 |
| `reedit`（Timeline 重新编辑） | 3 |

---

## 3. 可选：os_signpost / Points of Interest

`PerformanceTracker` 使用 `Logger(subsystem: "com.babycamera", category: "Performance")`。

在 **Console.app**（Mac）中：

1. 连接真机 → 选择设备 → 开始流式日志。
2. 过滤器：`subsystem:com.babycamera category:Performance`
3. 与 Xcode Console `[Performance]` 行互相印证。

---

## 4. 常见问题

| 现象 | 可能原因 | 处理 |
| --- | --- | --- |
| 相机 > 800 ms | 首次授权弹窗、Session 未预热 | 授权后重测；确认 App 前台预热逻辑 |
| 编辑器 > 500 ms | 大图 `CIImage` 同步加载 | 检查原图分辨率；记录 `photoId` 与文件大小 |
| 模拟器数值无意义 | 无真实 Camera / GPU | **必须真机**，模拟器 XCTest 会 Skip |
| Debug 比 Release 慢 | 调试符号 / 断言 | 验收以 Release/Profile 为准，Debug 日志仅作开发参考 |

---

## 5. 归档

1. 填写 [PERFORMANCE_REPORT.md](./PERFORMANCE_REPORT.md)
2. Instruments `.trace` 大文件放 `reports/YYYY-MM/traces/`（已 gitignore）
3. 完整 T7.6 多指标报告用 [PERF_BASELINE_REPORT_TEMPLATE.md](./PERF_BASELINE_REPORT_TEMPLATE.md)
