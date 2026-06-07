# 性能基线报告 — T7.6

> 复制本模板为 `reports/YYYY-MM/PERF_BASELINE_YYYYMMDD.md` 并填写实测数据。  
> 基线双机型：**iPhone 12** + **iPhone 16**。

## 元信息

| 字段 | 值 |
| --- | --- |
| 日期 | YYYY-MM-DD |
| Build / 版本 | e.g. `1.0.0 (1234)` |
| 环境 | mock / staging / production-canary |
| 执行人 | |
| Git SHA | |
| 关联 PR / 发布 | |

## 性能预算总览

| 指标 | 预算 | iPhone 12 | iPhone 16 | 结论 |
| --- | --- | --- | --- | --- |
| 相机冷启动 | ≤ 800 ms | | | ☐ Pass ☐ Fail |
| 编辑器打开 | ≤ 500 ms | | | ☐ Pass ☐ Fail |
| Feed 首屏 P95（缓存命中） | ≤ 500 ms | | | ☐ Pass ☐ Fail |
| AI 任务 P95（图） | ≤ 60 s | | | ☐ Pass ☐ Fail |
| AI 任务 P95（视频 5s） | ≤ 5 min | | | ☐ Pass ☐ Fail |

## 双机型矩阵 — 端侧（Instruments / XCTest）

### iPhone 12（LAB-IP12-001）

| 场景 | 测量方式 | 样本数 | P50 | P95 | Max | 预算 | Pass |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 相机冷启动 | Time Profiler · `PerformanceTracker` 日志 · viewWillAppear → 首帧预览 | | | | | 800 ms | |
| 编辑器打开 | `PerformanceTracker` 日志 · `editor_open` 埋点 | | | | | 500 ms | |
| Feed 首屏（端侧） | 本地缓存命中后首帧 | | | | | 500 ms | |
| 内存峰值（参考 T7.7） | Memory Gauge | | | | | 200 MB | |

**设备信息**

- 机型：iPhone 12
- OS：iOS ___
- UDID：LAB-IP12-001
- 网络：Wi-Fi / 5G

### iPhone 16（LAB-IP16-001）

| 场景 | 测量方式 | 样本数 | P50 | P95 | Max | 预算 | Pass |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 相机冷启动 | Time Profiler · `PerformanceTracker` 日志 | | | | | 800 ms | |
| 编辑器打开 | `PerformanceTracker` 日志 · `editor_open` 埋点 | | | | | 500 ms | |
| Feed 首屏（端侧） | 本地缓存命中后首帧 | | | | | 500 ms | |
| AI 玩法页打开 | 端侧首屏 | | | | | — | |

**设备信息**

- 机型：iPhone 16
- OS：iOS ___
- UDID：LAB-IP16-001

## API 压测 — 服务端 / Mock

> 命令：`tests/performance/benchmark-feed.sh` · `benchmark-ai-mock.sh`

### Feed `GET /v1/feeds/family`

| 环境 | 请求数 | Warmup | P50 (ms) | P95 (ms) | P99 (ms) | 预算 | Pass |
| --- | --- | --- | --- | --- | --- | --- | --- |
| mock @ localhost:18080 | | | | | | 500 ms | |
| staging-cn | | | | | | 500 ms | |

### AI 任务端到端（创建 → succeeded）

| 类型 | 环境 | 样本数 | P50 (s) | P95 (s) | Max (s) | 预算 | Pass |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 图像 ghibli_kid | mock | | | | | 60 s | |
| 图像 ghibli_kid | staging | | | | | 60 s | |
| 视频 5s video_walk | mock | | | | | 300 s | |
| 视频 5s video_walk | staging | | | | | 300 s | |

## 复现命令

```bash
# Mock API
cd tests/mocks/api && python3 mock_server.py

# Feed + AI
cd tests/performance
cp perf.env.example perf.env   # 按需修改
./benchmark-feed.sh
./benchmark-ai-mock.sh

# iOS stub / 真机前检查
./benchmark-ios-device.sh
```

真机 XCTest：

```bash
cd ios
xcodebuild test -scheme BabyCamera \
  -destination 'platform=iOS,name=LAB-IP12-001' \
  -only-testing:BabyCameraUITests/PerformanceBenchmarkTests
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
| 后端 | | |
