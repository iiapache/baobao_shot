# T7.6 性能压测基准

> 任务：**T7.6** · 对齐 [dev-plan.md](../../docs/dev-plan.md) §10.1  
> 机型矩阵：[device-matrix.md](./device-matrix.md)  
> 报告模板：[PERF_BASELINE_REPORT_TEMPLATE.md](./PERF_BASELINE_REPORT_TEMPLATE.md)

## 性能预算

| 指标 | 预算 | 脚本 / 测试 |
| --- | --- | --- |
| 相机冷启动 | ≤ 800 ms | `benchmark-ios-device.sh` · `PerformanceBenchmarkTests.swift` · `CameraStartupBenchmark` |
| 编辑器打开 | ≤ 500 ms | `benchmark-ios-device.sh` · `PerformanceBenchmarkTests.swift` · `EditorOpenBenchmark` |
| Feed 首屏 P95（缓存命中） | ≤ 500 ms | `benchmark-feed.sh` |
| AI 任务 P95（图） | ≤ 60 s | `benchmark-ai-mock.sh` |
| AI 任务 P95（视频 5s） | ≤ 5 min | `benchmark-ai-mock.sh` |

基线双机型：**iPhone 12**（下限）+ **iPhone 16**（上限）。

## 目录

```text
tests/performance/
├── README.md                              # 本文件
├── device-matrix.md                       # 机型矩阵与预算（T0.20）
├── perf.env.example                       # 环境变量模板
├── benchmark-feed.sh                      # Feed API curl 压测
├── benchmark-ai-mock.sh                   # AI mock 端到端延迟
├── benchmark-ios-device.sh                # iOS 端侧 stub 记录
├── run-benchmarks.sh                      # 一键跑 API + stub
├── PERF_BASELINE_REPORT_TEMPLATE.md       # 双机型报告模板
└── reports/                               # 运行产物（gitignore）

tests/e2e/ios/
└── PerformanceBenchmarkTests.swift          # iOS XCTest 占位（T7.6）

ios/Packages/BabyCameraCamera/             # CameraStartupBenchmark
ios/Packages/BabyCameraEditor/             # EditorOpenBenchmark
```

## 快速开始（Mock 模式）

```bash
# 1. 启动 Mock API
cd tests/mocks/api && python3 mock_server.py

# 2. 配置环境（可选）
cd ../../performance
cp perf.env.example perf.env

# 3. 语法检查（无需 mock 运行）
chmod +x benchmark-feed.sh benchmark-ai-mock.sh benchmark-ios-device.sh run-benchmarks.sh
./benchmark-feed.sh --syntax-check

# 4. 跑 Feed 压测（需 mock-api）
./benchmark-feed.sh

# 5. 跑 AI mock 延迟统计
./benchmark-ai-mock.sh

# 6. iOS 端侧 stub
./benchmark-ios-device.sh

# 7. 一键（API + stub）
./run-benchmarks.sh
```

预期末尾：

```text
[perf-feed] PERF FEED PASSED: P95=…ms ≤ 500ms
[perf-ai] PERF AI PASSED
[perf-ios] PERF IOS STUB PASSED
```

## Staging 模式

```bash
export BASE_URL=https://staging-api-cn.example.com
export PERF_FEED_REQUESTS=100
export PERF_AI_IMAGE_SAMPLES=20
./benchmark-feed.sh
./benchmark-ai-mock.sh
```

账号占位见 [accounts/test-accounts.yaml](../accounts/test-accounts.yaml)。

## iOS 真机基准

### XCTest（占位 + 预算断言）

SPM 单元测试（CI 可跑 stub）：

```bash
cd ios/Packages/BabyCameraCamera
swift test --filter CameraStartupBenchmarkTests

cd ../BabyCameraEditor
swift test --filter EditorOpenBenchmarkTests
```

端侧汇总占位（需 Xcode 工程引用后运行）：

```bash
cd ios
xcodebuild test \
  -scheme BabyCamera \
  -destination 'platform=iOS,name=LAB-IP12-001' \
  -only-testing:BabyCameraUITests/PerformanceBenchmarkTests
```

真机专项在 **LAB-IP12-001 / LAB-IP16-001** 上用 Instruments Time Profiler 测量，结果填入 [PERF_BASELINE_REPORT_TEMPLATE.md](./PERF_BASELINE_REPORT_TEMPLATE.md)。

### Shell stub（无真机时）

```bash
PERF_IOS_DEVICE_MODEL="iPhone 12" \
PERF_IOS_STUB_CAMERA_MS=720 \
PERF_IOS_STUB_EDITOR_MS=420 \
./benchmark-ios-device.sh
```

产出 JSON：`tests/performance/reports/YYYY-MM/ios-stub-*.json`

## 与 e2e 的关系

| 目录 | 用途 |
| --- | --- |
| `tests/e2e/` | 功能回归（P1–P7 场景闭环） |
| `tests/performance/` | 性能基准与 P95 预算（T7.6） |

性能脚本复用 e2e 登录凭据与 `tests/mocks/api/mock_server.py`，不替代 e2e 断言。

## 验收对照（T7.6）

| 验收项 | 实现 |
| --- | --- |
| Feed P95 ≤ 500ms | `benchmark-feed.sh` |
| AI 图 P95 ≤ 60s / 视频 ≤ 5min | `benchmark-ai-mock.sh` |
| 相机 ≤ 800ms / 编辑器 ≤ 500ms | `benchmark-ios-device.sh` + SPM Benchmark + `PerformanceBenchmarkTests.swift` |
| iPhone 12 + 16 双机型矩阵 | `device-matrix.md` + `PERF_BASELINE_REPORT_TEMPLATE.md` |
| 可复现文档 | 本 README |

## 相关任务

- T0.20：`device-matrix.md`
- T2.5：`CameraStartupBenchmark`
- T5.3：Feed P95 预算
- T7.6：本目录
- T7.7：崩溃率 / 内存 / 包体积（另项）
