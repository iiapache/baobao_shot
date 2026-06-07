# 埋点验证报告（Analytics Verification Report）

> 任务 **T7.9** · 对齐 [dev-plan.md §10.1](../dev-plan.md#101-子任务清单) · [design-ios.md §15](../design-ios.md#15-埋点核心事件清单--60-项)  
> 事件清单：[analytics-events-catalog.md](./analytics-events-catalog.md)  
> 校验脚本：`scripts/verify-analytics-events.sh`

---

## 1. 元信息

| 字段 | 值 |
| --- | --- |
| 报告 ID | `T7.9-YYYY-MM-DD-NN` |
| 执行人 | |
| 日期 | |
| 构建号 / Git SHA | |
| 环境 | `Debug` / `TestFlight` / `Staging` / `Prod` |
| 区域 | `CN` / `OS` |
| 网关 / ClickHouse | 集群地址 |

---

## 2. 验收标准（必达）

| 维度 | 标准 | 实测 | 结果 |
| --- | --- | --- | --- |
| 事件清单 | ≥ 60 项，与 design-ios §15 一致 | | ☐ Pass ☐ Fail |
| 常量化 | 100% 在 `AnalyticsEventCatalog.swift` | | ☐ Pass ☐ Fail |
| 代码引用 | `verify-analytics-events.sh` 无 missing | | ☐ Pass ☐ Fail |
| 公共字段 | 7 项齐全 | | ☐ Pass ☐ Fail |
| 上送策略 | 30s / 50 条 / 后台立即 | | ☐ Pass ☐ Fail |
| 落库 | 抽样事件在 ClickHouse 可查 | | ☐ Pass ☐ Fail |
| 隐私 | 无照片 / 文案原文 | | ☐ Pass ☐ Fail |

---

## 3. 静态校验（CI / 本地）

```bash
chmod +x scripts/verify-analytics-events.sh
./scripts/verify-analytics-events.sh
```

### 3.1 脚本输出摘要

| 指标 | 值 |
| --- | --- |
| Catalog 事件数 | |
| Swift 常量数 | |
| Missing in Swift | |
| Missing track | |
| Orphan in code | |
| 脚本结果 | ☐ PASS ☐ FAIL |

### 3.2 XCTest

```bash
cd ios && swift test --filter AnalyticsEventCatalogTests
```

| 用例 | 结果 |
| --- | --- |
| `testEventCountIsAtLeast60` | ☐ Pass |
| `testAllEventNamesAreUnique` | ☐ Pass |
| `testEmitAllStubTracksCoversCatalog` | ☐ Pass |

---

## 4. 分类覆盖矩阵

> 勾选表示：已触发 + ClickHouse 抽样确认。

| 分类 | 清单数 | 已触发 | ClickHouse | 备注 |
| --- | ---: | ---: | ---: | --- |
| 启动 / 生命周期 | 6 | | | |
| 账号 | 5 | | | |
| 家庭 | 6 | | | |
| 宝宝 | 3 | | | |
| 相机 | 7 | | | |
| 编辑 | 6 | | | |
| AI | 8 | | | |
| 时间线 | 4 | | | |
| 里程碑 | 3 | | | |
| 家庭圈 | 6 | | | |
| 分享 | 4 | | | |
| 积分 / 订阅 / 广告 | 7 | | | |
| 备份 | 4 | | | |
| 通知 | 2 | | | |
| 性能 / 缓存（扩展） | 2 | | | |
| **合计** | **73** | | | |

---

## 5. 公共字段抽样

从 ClickHouse 任取 3 条事件，核对 payload：

| 字段 | 事件 1 | 事件 2 | 事件 3 |
| --- | --- | --- | --- |
| `region` | | | |
| `userId`（hash） | | | |
| `babyId`（hash） | | | |
| `appVersion` | | | |
| `osVersion` | | | |
| `deviceModel` | | | |
| `sessionId` | | | |

---

## 6. 上送策略验证

| 场景 | 步骤 | 预期 | 实测 | 结果 |
| --- | --- | --- | --- | --- |
| 批量 30s | 连续操作 < 50 条，等待 35s | 一次 batch 上送 | | ☐ Pass |
| 批量 50 条 | 快速触发 50+ 事件 | 满 50 条立即上送 | | ☐ Pass |
| 后台立即 | Home 键切后台 | 立即 flush | | ☐ Pass |
| 弱网重试 | 飞行模式 → 恢复 | 队列不丢、补发 | | ☐ Pass |

---

## 7. 关键路径手测（建议）

| # | 路径 | 期望事件 | 已验证 |
| ---: | --- | --- | --- |
| 1 | 冷启动 | `app_launch`, `app_active` | ☐ |
| 2 | Apple 登录 | `login_attempt`, `login_success` | ☐ |
| 3 | 创建家庭 + 邀请 | `family_create`, `family_invite_generate` | ☐ |
| 4 | 拍照 → 编辑 → 保存 | `camera_capture`, `editor_open`, `editor_save_derived` | ☐ |
| 5 | AI 提交全流程 | `ai_submit` → `ai_success` / `ai_failure` | ☐ |
| 6 | 发布动态 + 点赞 | `post_publish`, `post_like` | ☐ |
| 7 | 备份授权 | `backup_authorize` | ☐ |
| 8 | 推送点击 | `push_notification_open` | ☐ |

---

## 8. 问题与跟进

| ID | 事件 / 分类 | 现象 | 严重度 | 负责人 | 状态 |
| --- | --- | --- | --- | --- | --- |
| | | | P0 / P1 / P2 | | Open / Fixed |

---

## 9. 结论

| 项 | 结论 |
| --- | --- |
| T7.9 总评 | ☐ 通过 ☐ 有条件通过 ☐ 不通过 |
| 阻塞项 | |
| 下一动作 | T7.12 TestFlight 内测前复验 |

---

## 附录 A：命令速查

```bash
# 静态校验
./scripts/verify-analytics-events.sh

# 严格模式（孤儿事件也 fail）
./scripts/verify-analytics-events.sh --strict

# 单测
cd ios && swift test --filter AnalyticsEventCatalogTests
```
