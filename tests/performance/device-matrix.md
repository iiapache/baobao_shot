# 性能基线机型清单

> 任务 **T0.20** · 对齐 [dev-plan.md](../../docs/dev-plan.md) T7.6 / T7.7 指标  
> 用途：性能回归、冒烟真机抽检、TestFlight Bug Bash 设备覆盖

## 1. 基线双机型（必测）

P0 起纳入 QA 资产池；P7 性能压测以这两台为 **primary baseline**。

| 优先级 | 机型 | 芯片 | RAM | 代表场景 | 最低 OS |
| --- | --- | --- | --- | --- | --- |
| P0 | **iPhone 12** | A14 | 4 GB | 存量用户下限、内存敏感 | iOS 17 |
| P0 | **iPhone 16** | A18 | 8 GB | 新旗舰、相机/AI 上限 | iOS 18 |

## 2. 扩展矩阵（推荐覆盖）

|  tier | 机型 | 芯片 | 说明 |
| --- | --- | --- | --- |
| 低端 | iPhone SE (3rd) | A15 | 小屏 + 单摄 |
| 中端 | iPhone 13 | A15 | 与 12 代际对照 |
| 中端 | iPhone 14 Pro | A16 | ProMotion、48MP |
| 高端 | iPhone 15 Pro Max | A17 Pro | 长焦 / 钛壳 |
| 高端 | iPhone 16 Pro Max | A18 Pro | 当前顶配 |

## 3. 性能预算（引用 dev-plan / design-ios）

| 指标 | 预算 | 测量方式 | 基线机型 |
| --- | --- | --- | --- |
| 相机冷启动 | ≤ 800 ms | Instruments Time Profiler | iPhone 12 |
| 编辑器打开 | ≤ 500 ms | 端侧埋点 `editor_open_ms` | iPhone 12 |
| Feed 首屏 P95 | ≤ 500 ms（缓存命中） | staging API + 端侧 | iPhone 12 / 16 |
| AI 任务 P95（图） | ≤ 60 s | ai-dispatch 链路 | iPhone 16 |
| AI 任务 P95（视频） | ≤ 5 min | ai-dispatch 链路 | iPhone 16 |
| 内存峰值 | ≤ 200 MB | Xcode Memory Gauge | iPhone 12 |
| 安装包体积 | ≤ 80 MB | Archive IPA | 通用 |
| Widget Extension | ≤ 5 MB | 编译产物 | 通用 |
| 崩溃率 | ≤ 0.2% | Bugly + Sentry | 全矩阵抽检 |

## 4. QA 实验室资产（占位）

| Asset ID | 机型 | UDID / 序列号 | 保管人 | 用途 |
| --- | --- | --- | --- | --- |
| LAB-IP12-001 | iPhone 12 | `<填写>` | QA | 性能基线 A |
| LAB-IP16-001 | iPhone 16 | `<填写>` | QA | 性能基线 B |
| LAB-IPSE3-001 | iPhone SE 3 | `<填写>` | QA | 小屏回归 |

## 5. 与测试账号 / 冒烟的关系

- `X-Device-Id` 建议使用 [test-accounts.yaml](../accounts/test-accounts.yaml) 中 `devices[].device_id`
- 冒烟脚本默认 `qa-device-iphone12-001`；性能专项切换为 `qa-device-iphone16-001`
- Staging 登录 + 拍照 mock + 发布 mock 在 **iPhone 12** 上至少通过 1 次真机抽测（P0-SMOKE）

## 6. 记录模板

每次性能 run 记录：

```text
Date:
Build:
Device:
OS:
Scenario:
Metric:
Result:
Pass/Fail:
Notes:
```

报告归档路径（建议）：`tests/performance/reports/YYYY-MM/`（gitignore 大附件）
