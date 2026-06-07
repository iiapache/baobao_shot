# UX-04 端侧性能验收报告 — 相机 / 编辑器

> **任务**：UX-04 · 对齐 [design-ios.md](../../docs/design-ios.md) §14  
> **归档**：复制为 `reports/YYYY-MM/PERFORMANCE_REPORT_YYYYMMDD.md` 并填写真机实测数据  
> **基线机型**：[device-matrix.md](./device-matrix.md) — iPhone 12 + iPhone 16

## 元信息

| 字段 | 值 |
| --- | --- |
| 日期 | YYYY-MM-DD |
| Build / 版本 | e.g. `1.0.0 (1234)` |
| Git SHA | |
| 执行人 | |
| 环境 | TestFlight / Debug 真机 / Release 真机 |
| 关联 PR / 发布 | |

## 验收阈值（design-ios §14）

| 指标 | 预算 | 测量起点 | 测量终点 |
| --- | --- | --- | --- |
| 相机冷启动 | **≤ 800 ms** | 相机 Tab `viewWillAppear`（授权通过后 session 启动） | 首帧预览上屏 |
| 编辑器打开 | **≤ 500 ms** | 触发 `presentEditor` | 编辑器 UI 可交互（`activeSession` 呈现） |

## 测量方法（任选 / 可交叉验证）

### 方法 A — 端侧日志（推荐，零 Instruments 依赖）

1. Xcode 连接真机，Run **Debug** 构建（`PerformanceTracker` 会 `print` 日志）。
2. 打开 **Console**，过滤关键字：`[Performance]`
3. 执行场景并记录日志行：

```text
[Performance] camera_cold_start source=camera_tab elapsed=XXXms budget=800ms PASS|FAIL
[Performance] editor_open source=camera elapsed=XXXms budget=500ms PASS|FAIL
```

4. 或使用脚本采集：

```bash
cd tests/performance
./benchmark-ios-startup.sh --collect-guide
```

### 方法 B — Xcode Instruments Time Profiler

详见 [INSTRUMENTS_GUIDE.md](./INSTRUMENTS_GUIDE.md)。

### 方法 C — SPM 基准测试（CI / 预算常量校验）

```bash
cd ios/Packages/BabyCameraCamera && swift test --filter CameraStartupBenchmarkTests
cd ../BabyCameraEditor && swift test --filter EditorOpenBenchmarkTests
cd ../BabyCameraDiagnostics && swift test --filter PerformanceTrackerTests
```

> 真机专项用例在模拟器上 `XCTSkip`；需在 LAB-IP12-001 / LAB-IP16-001 上取消 skip 或使用方法 A/B。

## 真机实测 — iPhone 12（LAB-IP12-001）

**设备信息**

| 字段 | 值 |
| --- | --- |
| 机型 | iPhone 12 |
| OS | iOS ___ |
| UDID | LAB-IP12-001 |
| 网络 | Wi-Fi / 5G / 离线 |
| 相机权限 | 已授权 ☐ |

### 相机冷启动（≤ 800 ms）

| 轮次 | 耗时 (ms) | 日志 / Instruments 截图 | Pass |
| --- | --- | --- | --- |
| 1（冷启动后首次进入相机 Tab） | | | ☐ |
| 2（切 Tab 再返回） | | | ☐ |
| 3（杀进程后重进） | | | ☐ |
| **P50** | | | |
| **P95** | | | |
| **Max** | | | |

**结论**：☐ Pass（P95 ≤ 800 ms） ☐ Fail

### 编辑器打开（≤ 500 ms）

| 轮次 | 来源 (`source`) | 耗时 (ms) | Pass |
| --- | --- | --- | --- |
| 1（拍照后进入编辑） | camera | | ☐ |
| 2（Timeline 重新编辑） | reedit | | ☐ |
| 3（选图进入编辑） | camera | | ☐ |
| **P50** | | | |
| **P95** | | | |
| **Max** | | | |

**结论**：☐ Pass（P95 ≤ 500 ms） ☐ Fail

## 真机实测 — iPhone 16（LAB-IP16-001）

> 同上表格复制填写；iPhone 16 为上限参考，预算阈值不变。

| 指标 | P50 (ms) | P95 (ms) | Max (ms) | 预算 | 结论 |
| --- | --- | --- | --- | --- | --- |
| 相机冷启动 | | | | 800 ms | ☐ Pass ☐ Fail |
| 编辑器打开 | | | | 500 ms | ☐ Pass ☐ Fail |

## 汇总

| 指标 | iPhone 12 | iPhone 16 | 总评 |
| --- | --- | --- | --- |
| 相机冷启动 ≤ 800 ms | ☐ Pass ☐ Fail | ☐ Pass ☐ Fail | ☐ **UX-04 通过** |
| 编辑器打开 ≤ 500 ms | ☐ Pass ☐ Fail | ☐ Pass ☐ Fail | |

## 复现命令

```bash
# 预算常量 + 测量逻辑单测
cd ios/Packages/BabyCameraDiagnostics && swift test --filter PerformanceTrackerTests
cd ../BabyCameraCamera && swift test --filter CameraStartupBenchmarkTests
cd ../BabyCameraEditor && swift test --filter EditorOpenBenchmarkTests

# 真机 XCTest 占位（需 Xcode 工程 + 真机 destination）
cd ios
xcodebuild test -scheme BabyCamera \
  -destination 'platform=iOS,name=LAB-IP12-001' \
  -only-testing:BabyCameraUITests/PerformanceBenchmarkTests

# Stub JSON（无真机时的流程占位，不可替代真机验收）
cd tests/performance
PERF_IOS_DEVICE_MODEL="iPhone 12" \
PERF_IOS_STUB_CAMERA_MS=720 \
PERF_IOS_STUB_EDITOR_MS=420 \
./benchmark-ios-device.sh
```

## 异常与备注

| 编号 | 现象 | 根因 | 跟进 |
| --- | --- | --- | --- |
| 1 | | | |
| 2 | | | |

## 签署

| 角色 | 姓名 | 日期 |
| --- | --- | --- |
| QA | | |
| iOS | | |
