# 崩溃率 / 内存 / 安装包压测报告

> 任务 **T7.7** · 对齐 [dev-plan.md §10.1](../dev-plan.md#101-子任务清单) · [design-ios.md §14](../design-ios.md#14-性能预算与冷启动)

---

## 1. 元信息

| 字段 | 值 |
| --- | --- |
| 报告 ID | `T7.7-YYYY-MM-DD-NN` |
| 执行人 | |
| 日期 | |
| 构建号 / Git SHA | |
| 渠道 | `Debug` / `TestFlight` / `App Store Connect` |
| 区域 | `CN` / `OS` |
| 基线文档 | [tests/performance/device-matrix.md](../../tests/performance/device-matrix.md) |

---

## 2. 验收预算（必达）

| 维度 | 预算 | 实测 | 结果 |
| --- | --- | --- | --- |
| 崩溃率（7 日 / 会话） | ≤ 0.2% | | ☐ Pass ☐ Fail |
| 内存峰值（常驻） | ≤ 200 MB | | ☐ Pass ☐ Fail |
| 安装包（主包 IPA 压缩后） | ≤ 80 MB | | ☐ Pass ☐ Fail |
| 崩溃双采集 | Bugly + Sentry 均收到事件 | | ☐ Pass ☐ Fail |
| ODR 分包 | 贴纸 / 字体不计入主包 80 MB | | ☐ Pass ☐ Fail |

---

## 3. 崩溃率（Bugly + Sentry 双采集）

### 3.1 采集配置

| SDK | 配置项 | 值 | 备注 |
| --- | --- | --- | --- |
| Sentry | DSN | `Info-Supplement.plist → SentryDSN` | stub / 实装 |
| Sentry | Environment | | dev / staging / prod |
| Bugly | AppID | `Info-Supplement.plist → BuglyAppID` | stub / 实装 |
| 开关 | CrashReportingEnabled | YES / NO | |

### 3.2 Smoke Test

| 步骤 | Sentry Issues | Bugly 控制台 | 时间 |
| --- | --- | --- | --- |
| 触发 `SentryReportingStub.captureSmokeTestError()` | ☐ 可见 | N/A | |
| TestFlight 测试崩溃（手动） | ☐ 可见 | ☐ 5min 内可见 | |

### 3.3 压测场景（建议 ≥ 30 分钟 / 机型）

| 场景 | 会话数 | 崩溃数 | 崩溃率 | 备注 |
| --- | --- | --- | --- | --- |
| 冷启动 → 首页 | | | | |
| 相机拍摄 20 张 | | | | |
| 编辑器完整流程 | | | | |
| AI 提交（图） | | | | |
| 后台切换 ×10 | | | | |
| **合计** | | | | |

**崩溃率公式**：`崩溃会话数 / 总会话数 × 100%`

---

## 4. 内存峰值（≤ 200 MB）

### 4.1 测量方式

- **工具 A**：Xcode Debug → Memory Gauge（iPhone 12 真机）
- **工具 B**：`MemoryFootprintSampler`（DEBUG 构建，`BabyCameraDiagnostics`）

```swift
#if DEBUG
let sample = MemoryFootprintSampler.shared.sample()
print(MemoryFootprintSampler.shared.formattedSummary(sample: sample))
#endif
```

### 4.2 场景记录

| 场景 | 机型 | OS | 峰值 (MB) | 预算 | 结果 |
| --- | --- | --- | --- | --- | --- |
| 冷启动后首页 idle | iPhone 12 | | ≤ 200 | | |
| 相机预览 + 连拍 | iPhone 12 | | ≤ 200 | | |
| 编辑器（贴纸 + 字体 ODR 已加载） | iPhone 12 | | ≤ 200 | | |
| Feed 滚动 100 条 | iPhone 12 | | ≤ 200 | | |
| AI 任务进行中 | iPhone 16 | | ≤ 200 | | |

### 4.3 超标分析（若有）

| 场景 | 峰值 | 疑似原因 | 跟进 Issue |
| --- | --- | --- | --- |
| | | | |

---

## 5. 安装包体积（≤ 80 MB）

### 5.1 测量命令

```bash
# IPA
./scripts/measure-ipa-size.sh /path/to/BabyCamera.ipa

# xcarchive
./scripts/measure-ipa-size.sh ~/Library/Developer/Xcode/Archives/.../BabyCamera.xcarchive
```

### 5.2 体积明细

| 组件 | 未压缩 (MB) | 估算安装 (MB) | 备注 |
| --- | --- | --- | --- |
| 主 App (.app) | | | |
| 内嵌 Frameworks | | | |
| Widget Extension | | | 预算 ≤ 5 MB（独立） |
| **主包合计（脚本 INSTALL_SIZE）** | | **≤ 80** | |
| ODR `editor-fonts` | | 按需 | 不计入主包 |
| ODR `editor-stickers` | | 按需 | 不计入主包 |

### 5.3 ODR 压缩说明

> 贴纸与装饰字体通过 **On-Demand Resources** 在用户首次使用编辑功能时下载。  
> 主包 Archive 使用 `measure-ipa-size.sh` 验收；完整用户体验体积见 App Store Connect → App Size。  
> 配置详见 [ios/ODR/README.md](../../ios/ODR/README.md)。

| ODR Tag | 内容 | 预估 | 首次加载点 |
| --- | --- | --- | --- |
| `editor-fonts` | TTF 字体 | ~15 MB | TextStep |
| `editor-stickers` | 贴纸包 | ~25 MB | StickerStep |

---

## 6. 机型矩阵

| 优先级 | 机型 | 是否执行 | 崩溃 | 内存 | 包体 |
| --- | --- | --- | --- | --- | --- |
| P0 | iPhone 12 | ☐ | | | |
| P0 | iPhone 16 | ☐ | | | |

---

## 7. 结论与签字

| 项 | 结论 |
| --- | --- |
| T7.7 总体验收 | ☐ **通过** ☐ **不通过** |
| 阻塞项 | |
| 回流任务 | |

| 角色 | 姓名 | 日期 |
| --- | --- | --- |
| QA | | |
| iOS | | |
| 研发负责人 | | |

---

## 8. 附件

- [ ] `measure-ipa-size.sh` 终端输出截图 / 日志
- [ ] Sentry Issues 链接
- [ ] Bugly 控制台截图
- [ ] Instruments Memory  trace（可选）
- [ ] App Store Connect App Size 截图（含 ODR）

归档建议：`docs/qa/reports/T7.7/YYYY-MM/`（大附件可 gitignore）
