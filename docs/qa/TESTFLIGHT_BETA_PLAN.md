# TestFlight 内测计划（T7.12）

> 任务 **T7.12** · 对齐 [dev-plan.md §10.1](../dev-plan.md#101-子任务清单)  
> 验收：**30 名内测用户** · **7 天观察** · **崩溃率 ≤ 0.2%**

---

## 1. 目标与范围

| 项 | 说明 |
| --- | --- |
| 构建渠道 | TestFlight External Testing（外部测试组） |
| 上传入口 | `cd ios && bundle exec fastlane beta`（见 [Fastfile](../../ios/fastlane/Fastfile)） |
| 构建检查清单 | [TESTFLIGHT_BUILD_CHECKLIST.md](./TESTFLIGHT_BUILD_CHECKLIST.md)（ENV-02） |
| 冒烟门禁 | `tests/e2e/smoke-critical-path.sh` 全绿后方可邀请内测 |
| Bug Bash | 见 [BUG_BASH_CHECKLIST.md](./BUG_BASH_CHECKLIST.md) |
| 崩溃采集 | Bugly + Sentry 双通道（见 [CRASH_MEMORY_SIZE_REPORT_TEMPLATE.md](./CRASH_MEMORY_SIZE_REPORT_TEMPLATE.md)） |

**不在本阶段范围**：App Store 正式提审（T7.13）、Phased Release 放量（T7.14）。

---

## 2. 内测用户招募（N = 30）

### 2.1 来源与筛选

| 渠道 | 目标人数 | 筛选条件 |
| --- | --- | --- |
| 核心种子用户（产品/运营人脉） | 8 | 有 0–3 岁宝宝；日活意愿高；可填每日反馈表 |
| 亲友真实家庭 | 10 | 至少 2 人共用同一家庭圈（覆盖邀请加入链路） |
| 外部宝妈社群 | 8 | 接受录屏反馈；签署内测保密约定 |
| 工程/QA 志愿（Dogfood） | 4 | 熟悉 TestFlight；可复现崩溃并导出日志 |

**硬性排除**：越狱设备、Beta 版 iOS、无中国大陆手机号（CN 包）、未签署监护人同意书测试账号。

### 2.2 设备矩阵（最低覆盖）

| 机型档 | 人数 | 代表机型 |
| --- | --- | --- |
| 低端 | ≥ 6 | iPhone 12 / SE (3rd) |
| 中端 | ≥ 14 | iPhone 14 / 15 |
| 高端 | ≥ 6 | iPhone 16 Pro 系列 |
| iPad（可选） | ≥ 2 | iPad (10th) |

### 2.3 入驻流程

1. 收集 Apple ID 邮箱 → 录入 App Store Connect External Testers
2. 发送 TestFlight 邀请 + [内测须知](./BUG_BASH_CHECKLIST.md#8-反馈与升级通道)（反馈渠道、日志导出、禁止公开截图含未脱敏宝宝照）
3. 首日完成：安装 → 登录 → 创建/加入家庭 → 完成监护人同意书
4. 记录入组日期 `D0`，纳入 7 日观察窗口

---

## 3. 分组策略

30 人分为 **3 组 × 10 人**，按「主测场景」分工，**所有组均须每日完成关键路径冒烟（端侧手动 5 分钟版）**。

| 组别 | 代号 | 人数 | 主测模块 | 每日最低操作 |
| --- | --- | --- | --- | --- |
| A | `CORE` | 10 | 账号 · 家庭 · 发布 · Feed | 登录 → 拍/选图 → 发布 → 浏览家庭圈 → 点赞评论 |
| B | `AI` | 10 | AI 玩法 · 积分 · 订阅 | 图像玩法 ×2 · 视频 5s ×1 · 查看积分消耗与退还 |
| C | `PLUS` | 10 | 备份 · Widget · 设置 · 分享 | Widget 刷新 · 备份队列 · 数据导出抽样 · 微信/系统分享 |

### 3.1 交叉覆盖（防漏测）

| 日历日 | 全组共同任务 |
| --- | --- |
| D0 | 安装、登录、家庭初始化、同意书 |
| D1 | 关键路径（相机 → 发布 → Feed） |
| D2 | AI 图像 happy path + 失败态截图 |
| D3 | 双用户家庭互动（邀请成员） |
| D4 | 备份 Provider 任选其一连通 |
| D5 | 设置中心全页滑动 + 通知开关 |
| D6 | Bug Bash 集中 2h（见 Checklist） |
| D7 | 回归验证 + 问卷 |

---

## 4. 七天观察指标

### 4.1 必达门槛（Go / No-Go）

| 指标 | 阈值 | 数据源 | 判定 |
| --- | --- | --- | --- |
| **崩溃率** | ≤ **0.2%** | Bugly + Sentry（会话级） | 7 日滑动窗口 |
| 关键路径成功率 | ≥ 98% | `smoke-critical-path.sh` + 手动签到 | 每日 1 次 CI + 每组 ≥3 人复验 |
| P0 阻断 Bug | 0  open | Jira/飞书缺陷单 | 崩溃 / 丢图 / 无法登录 |
| 平均冷启动 | ≤ 2.5s | 真机抽样（≥10 台） | 超预算记 P1 |
| Feed P95（缓存命中） | ≤ 500ms | Grafana `feed-svc` | 内测环境 staging |

**崩溃率公式**：

```text
崩溃率 = 崩溃会话数 / 总会话数 × 100%
```

与会话定义对齐 Bugly「访问次数」/ Sentry Release Health。

### 4.2 每日记录表

| 日期 | 活跃内测用户 | 总会话 | 崩溃会话 | 崩溃率 | 新增 P0 | 新增 P1 | smoke CI | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D0 | | | | | | | | |
| D1 | | | | | | | | |
| D2 | | | | | | | | |
| D3 | | | | | | | | |
| D4 | | | | | | | | |
| D5 | | | | | | | | |
| D6 | | | | | | | | |
| D7 | | | | | | | | |

### 4.3 辅助观测

| 类别 | 指标 | 说明 |
| --- | --- | --- |
| 留存 | D1 / D3 / D7 留存率 | 目标 D7 ≥ 60%（30 人中 ≥18 人仍活跃） |
| AI | 任务成功率、P95 耗时 | 图 ≤ 60s，视频 5s ≤ 300s |
| 审核 | UGC 误杀申诉数 | 24h 内响应 |
| 性能 | 内存峰值 > 200MB 次数 | 真机 Feedback 附 Instruments 截图 |
| 包体 | IPA 大小 | ≤ 80MB（见 T7.7） |

---

## 5. 构建与分发

```bash
# 1. 本地/CI 冒烟（mock API）
cd tests/mocks && docker compose up -d mock-api   # 或 python3 api/mock_server.py
cd ../e2e && chmod +x smoke-critical-path.sh && ./smoke-critical-path.sh

# 2. TestFlight 上传（macOS + 证书就绪后）
cd ios
export MATCH_PASSWORD='***'          # GitLab CI Variable
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD='***'  # 可选
bundle exec fastlane beta
```

| 步骤 | 负责人 | 产物 |
| --- | --- | --- |
| 递增 Build 号 | iOS | `CFBundleVersion` / CI `$CI_PIPELINE_IID` |
| `fastlane beta` | iOS | `.ipa` → TestFlight |
| External Group 发布 | 运营 | 30 人可见 |
|  Release Notes | 产品 | 中文更新说明 + 已知问题 |

---

## 6. 退出标准与决策

| 结果 | 条件 | 下一步 |
| --- | --- | --- |
| **通过** | 7 日内崩溃率 ≤ 0.2%，P0 = 0，smoke 连续 7 天绿 | 进入 T7.13 提审材料冻结 |
| **有条件通过** | 崩溃率 ≤ 0.2%，存在已修复 P1 且回归完成 | 发补丁 build，缩短观察至 3 天 |
| **不通过** | 崩溃率 > 0.2% 或 P0 ≥ 1 | 暂停拉新，Hotfix 分支 + 重新 7 天观察 |

---

## 7. 交付物

| 文件 | 用途 |
| --- | --- |
| 本文件 | 招募、分组、7 日指标 |
| [BUG_BASH_CHECKLIST.md](./BUG_BASH_CHECKLIST.md) | 模块分工与缺陷记录 |
| [CRASH_MEMORY_SIZE_REPORT_TEMPLATE.md](./CRASH_MEMORY_SIZE_REPORT_TEMPLATE.md) | 崩溃率实测填写 |
| `tests/e2e/smoke-critical-path.sh` | 关键路径自动化冒烟 |
| 内测总结报告 `T7.12-YYYY-MM-DD.md`（观察期结束后） | Go/No-Go 结论 |

---

## 8. 风险与应对

| 风险 | 应对 |
| --- | --- |
| TestFlight 审核延迟 | 提前 48h 提交 build；准备 Beta App Review 说明 |
| 样本不足 30 人 | 运营补位；观察期延长至 10 天但不改崩溃阈值 |
| 崩溃率统计口径不一致 | 以 Bugly 为主、Sentry 交叉验证，取较高值 |
| 内测反馈含未脱敏照片 | 反馈渠道自动提醒；运营人工复核 |
