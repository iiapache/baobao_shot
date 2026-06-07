# BabyCamera 上线后 D1 / D7 监控检查表（T7.15）

> App Store 渐进发布（T7.14）完成后，在第 **1** 天与第 **7** 天各执行一次本检查表。  
> 指标快照脚本：`scripts/ops/d1-d7-metrics-snapshot.sh`  
> 阈值来源：`docs/dev-plan.md` P7 完成判定 + [METRICS_CATALOG.md](./METRICS_CATALOG.md) + [infra/monitoring/prometheus/alerts/babycamera-v1.yaml](../../infra/monitoring/prometheus/alerts/babycamera-v1.yaml)

---

## 使用说明

1. 复制本表到 `docs/ops/records/D1_D7-YYYYMMDD.md`（或 spreadsheet）
2. 运行快照脚本填入「实测值」列：

```bash
# 生产（需 PROMETHEUS_URL / GRAFANA_URL）
./scripts/ops/d1-d7-metrics-snapshot.sh --day 1 --region cn --output docs/ops/records/snapshots/d1-cn.json

# 本地 / CI 无监控栈时用 mock
./scripts/ops/d1-d7-metrics-snapshot.sh --day 1 --mock --output /tmp/d1-mock.json
```

3. 任一 **P0 指标** 未达标 → 按 [INCIDENT_RESPONSE_PLAYBOOK.md](./INCIDENT_RESPONSE_PLAYBOOK.md) 开 incident
4. D7 需对比 D1 快照，关注趋势恶化（非单点尖峰）

---

## 基本信息

| 字段 | D1 | D7 |
| --- | --- | --- |
| 检查日期 | YYYY-MM-DD | YYYY-MM-DD |
| 上线日期（Day 0） | YYYY-MM-DD | （同左） |
| Phased Release 阶段 | Day __ / 7 | 100% / 完成 |
| 检查人 | | |
| On-call 主值班 | 见 [ONCALL_ROSTER](./ONCALL_ROSTER_TEMPLATE.md) | |
| 快照文件路径 | | |

---

## 1. 端侧与健康（P7 完成判定）

| # | 指标 | 阈值 | D1 实测 | D7 实测 | D1 ✓ | D7 ✓ | 数据源 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1.1 | 崩溃率（Crash-free sessions） | ≤ **0.2%** | | | ☐ | ☐ | Bugly + Sentry |
| 1.2 | 安装包大小 | ≤ 80MB | | | ☐ | ☐ | App Store Connect |
| 1.3 | 内存峰值（iPhone 12 抽检） | ≤ 200MB | | | ☐ | ☐ | Instruments / QA |
| 1.4 | App Store 评分 / 1星占比 | 无异常洪峰 | | | ☐ | ☐ | ASC / 客服 |

---

## 2. API 与网关

| # | 指标 | 阈值 | D1 实测 | D7 实测 | D1 ✓ | D7 ✓ | PromQL / 面板 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.1 | 全局 5xx 率 | < **0.1%**（告警 1%） | | | ☐ | ☐ | `BabyCameraGatewayHigh5xxRate` |
| 2.2 | 核心服务 5xx（feed/auth/ai） | < 0.1% | | | ☐ | ☐ | `traces_spanmetrics_calls_total` |
| 2.3 | Feed P95（缓存命中） | ≤ **500ms** | | | ☐ | ☐ | `babycamera_feed_request_duration_seconds` |
| 2.4 | API P95（非 Feed） | < 2s | | | ☐ | ☐ | Grafana Overview |

**区域**：☐ ack-cn　☐ eks-os（双区域分别填）

---

## 3. AI 任务

| # | 指标 | 阈值 | D1 实测 | D7 实测 | D1 ✓ | D7 ✓ | 告警 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3.1 | AI 任务成功率（10m） | ≥ **95%** | | | ☐ | ☐ | `BabyCameraAITaskLowSuccessRate` |
| 3.2 | 图片任务 P95 | ≤ **60s** | | | ☐ | ☐ | `BabyCameraAIImageP95TooSlow` |
| 3.3 | 视频任务 P95 | ≤ **300s** | | | ☐ | ☐ | `BabyCameraAIVideoP95TooSlow` |
| 3.4 | Adapter 队列深度 | 无持续积压 | | | ☐ | ☐ | `babycamera_ai_adapter_queue_depth` |
| 3.5 | 远端灰度玩法 | 无故障 style 未下架 | | | ☐ | ☐ | config-svc 审计 |

---

## 4. IAP / 商业化

| # | 指标 | 阈值 | D1 实测 | D7 实测 | D1 ✓ | D7 ✓ | 告警 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 4.1 | IAP 校验成功率 | ≥ **99.5%** | | | ☐ | ☐ | `BabyCameraIAPVerifyHighFailureRate` |
| 4.2 | 积分对账差异 | **= 0** | | | ☐ | ☐ | `BabyCameraCreditReconciliationDiscrepancy` |
| 4.3 | 上次对账时间 | < 24h | | | ☐ | ☐ | `babycamera_credit_reconciliation_last_run_timestamp_seconds` |
| 4.4 | 广告激励重复率 | 无异常 spike | | | ☐ | ☐ | `babycamera_ad_reward_total` |

---

## 5. Feed / UGC / 审核

| # | 指标 | 阈值 | D1 实测 | D7 实测 | D1 ✓ | D7 ✓ | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5.1 | UGC 发布成功率 | ≥ 99% | | | ☐ | ☐ | |
| 5.2 | 审核 error 率 | < 1% | | | ☐ | ☐ | `babycamera_audit_request_total{result="error"}` |
| 5.3 | 申诉 backlog | 24h SLA 内 | | | ☐ | ☐ | T7.5 |
| 5.4 | OSS 撤回对账差异 | = 0 | | | ☐ | ☐ | `babycamera_feed_oss_reconcile_discrepancy_total` |

---

## 6. 推送（APNs）

| # | 指标 | 阈值 | D1 实测 | D7 实测 | D1 ✓ | D7 ✓ | 告警 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 6.1 | APNs 失败率（10m） | < **1%** | | | ☐ | ☐ | `BabyCameraAPNsHighFailureRate` |
| 6.2 | unregistered token 占比 | 无异常激增 | | | ☐ | ☐ | |
| 6.3 | 互动推送 E2E 抽检 | 30s 内送达 | | | ☐ | ☐ | `tests/e2e/p5-e2e.sh` |

---

## 7. 微信 SDK（端侧 + 配置）

| # | 检查项 | 预期 | D1 | D7 | 备注 |
| --- | --- | --- | --- | --- | --- |
| 7.1 | 分享好友 / 朋友圈 | 真机通过 | ☐ | ☐ | |
| 7.2 | 未安装微信 → 系统分享 | 422 + 兜底可用 | ☐ | ☐ | |
| 7.3 | Universal Link 探活 | 200 / 正确跳转 | ☐ | ☐ | |
| 7.4 | 客诉「分享失败」占比 | 无 D1/D7 尖峰 | ☐ | ☐ | 客服 |

> 微信故障通常无服务端 Prometheus 指标，依赖端侧埋点 + 客诉 + 演练。

---

## 8. 告警与 On-call

| # | 检查项 | D1 | D7 |
| --- | --- | --- | --- |
| 8.1 | P0 告警数量（24h / 7d） | ___ 条 | ___ 条 |
| 8.2 | 未 ACK 告警 | ☐ 无 | ☐ 无 |
| 8.3 | 未关闭 incident | ☐ 无 | ☐ 无 |
| 8.4 | On-call 表已更新 | ☐ | ☐ |
| 8.5 | 五类故障演练记录 | ☐ 已归档 | ☐ 复核 |

---

## 9. D1 → D7 趋势对比

| 指标 | D1 值 | D7 值 | 变化 | 需 action |
| --- | --- | --- | --- | --- |
| 崩溃率 | | | | ☐ |
| AI 成功率 | | | | ☐ |
| IAP 成功率 | | | | ☐ |
| Feed P95 | | | | ☐ |
| DAU / 留存（可选） | | | | ☐ |

**趋势恶化定义**：连续 2 天低于阈值，或 D7 较 D1 劣化 > 20%（相对）。

---

## 10. 检查结论

| 项 | D1 | D7 |
| --- | --- | --- |
| 总体结论 | ☐ 通过　☐ 有风险　☐ 不通过 | ☐ 通过　☐ 有风险　☐ 不通过 |
| P0 指标全部达标 | ☐ | ☐ |
| 需开 incident | ☐ 否　☐ 是（INC-____） | ☐ 否　☐ 是 |
| 需延长 phased release | ☐ | ☐ |
| 签字 | ________ | ________ |

**不通过 / 有风险说明：**

> （填写）

---

## 相关文档

- Incident 流程：[INCIDENT_RESPONSE_PLAYBOOK.md](./INCIDENT_RESPONSE_PLAYBOOK.md)
- 技术止血：[RUNBOOK.md](./RUNBOOK.md)
- 值班表：[ONCALL_ROSTER_TEMPLATE.md](./ONCALL_ROSTER_TEMPLATE.md)
- 演练记录：[records/INCIDENT_DRILL_RECORD_TEMPLATE.md](./records/INCIDENT_DRILL_RECORD_TEMPLATE.md)
