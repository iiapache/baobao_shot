# On-Call 值班表模板（T7.10 / T7.15）

> 复制本文件为 `ONCALL_ROSTER_YYYY-MM.md`，由 INFRA 每季度更新。  
> 告警通道：钉钉 + 飞书（P1/P2）；电话（P0 critical）。  
> **Incident 流程**：[INCIDENT_RESPONSE_PLAYBOOK.md](./INCIDENT_RESPONSE_PLAYBOOK.md) · **D1/D7 检查**：[D1_D7_MONITORING_CHECKLIST.md](./D1_D7_MONITORING_CHECKLIST.md)

## 告警分级

| 级别 | `severity` 标签 | 通知渠道 | 响应 SLA | 示例告警 |
| --- | --- | --- | --- | --- |
| P0 | `critical` | 钉钉 + 飞书 + **电话** | 15 分钟 | 5xx > 1%、AI 成功率 < 95%、积分对账差异、APNs 失败 > 1% |
| P1 | `warning` | 钉钉 + 飞书 | 30 分钟 | Feed P95 > 800ms、AI P95 超时、对账任务停滞 |
| P2 | `info` | 飞书 | 下一工作日 | 非生产环境、演练告警 |

## Webhook 配置（占位）

| 变量 | 用途 | 占位值 |
| --- | --- | --- |
| `DINGTALK_WEBHOOK_URL` | 钉钉群机器人 | `https://oapi.dingtalk.com/robot/send?access_token=__REPLACE__` |
| `FEISHU_WEBHOOK_URL` | 飞书群机器人 | `https://open.feishu.cn/open-apis/bot/v2/hook/__REPLACE__` |
| `ONCALL_PHONE_WEBHOOK_URL` | P0 电话外呼（PagerDuty / 阿里云语音） | `https://oncall.example.com/api/v1/alert/__REPLACE__` |

配置位置：`infra/monitoring/prometheus/alertmanager-config-snippet.yaml`（通过 Vault Secret 注入，勿明文提交）。

---

## 值班轮换表

| 周期 | 主值班（Primary） | 副值班（Secondary） | 升级联系人（Escalation） |
| --- | --- | --- | --- |
| W{{WEEK}} {{DATE_RANGE}} | {{PRIMARY_NAME}} / {{PRIMARY_PHONE}} | {{SECONDARY_NAME}} / {{SECONDARY_PHONE}} | {{ESCALATION_NAME}} / {{ESCALATION_PHONE}} |
| W{{WEEK}} {{DATE_RANGE}} | | | |
| W{{WEEK}} {{DATE_RANGE}} | | | |
| W{{WEEK}} {{DATE_RANGE}} | | | |

> 主值班负责 ACK、初步诊断、拉副值班；15 分钟未 ACK 或 P0 未止血，副值班升级 Escalation。

---

## 团队分工

| `team` 标签 | 负责域 | 默认主值班角色 |
| --- | --- | --- |
| `infra` | K8s、网关、Prometheus/Grafana、OTEL | SRE |
| `backend` | feed / auth / notification / media | 后端 on-call |
| `ai` | ai-dispatch-svc、模型路由、审核链路 | AI 后端 on-call |
| `commerce` | credit-sub-ad-svc、IAP、广告、对账 | 商业化后端 on-call |

---

## 值班 SOP（简版）

### 1. 收到告警

1. 在钉钉 / 飞书 ACK（回复「收到，正在处理」）
2. 打开 Grafana → **BabyCamera v1 Overview**（uid: `babycamera-v1-overview`）
3. 按告警 `team` 标签拉对应负责人

### 2. 常见告警处置

| 告警 | 第一步 | 止血 |
| --- | --- | --- |
| `BabyCameraAPIHigh5xxRate` | Grafana 看 5xx 占比面板，查 Loki 错误日志 | 回滚最近发布 / 扩容 |
| `BabyCameraAITaskLowSuccessRate` | 查 ai-dispatch 队列深度、模型 adapter 成功率 | 切换模型路由 / 暂停高成本玩法 |
| `BabyCameraCreditReconciliationDiscrepancy` | 查 `credit_reconciliation_runs` 审计表 | 冻结异常账户调账，通知 commerce |
| `BabyCameraAPNsHighFailureRate` | 查 APNs 证书过期、device token 失效率 | 轮换证书 / 清理失效 token |
| `BabyCameraFeedP95TooSlow` | 查 Redis 缓存命中率 | 预热缓存 / 扩容 feed-svc |
| `BabyCameraMetricsScrapeDown` | `kubectl get pods -n observability` | 重启 exporter / 修复 ServiceMonitor |

### 3. 事后

- 30 分钟内写 incident 摘要（时间线、根因、止血动作）
- 24 小时内补 postmortem（P0 必填）
- 需要代码修复时开 JIRA / Linear ticket，关联告警名

---

## 演练记录

| 日期 | 类型 | 参与人 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| {{DATE}} | 告警路由演练 | | ☐ 通过 | 钉钉 / 飞书 / 电话各 1 条测试告警 |
| {{DATE}} | 对账差异演练 | | ☐ 通过 | 手动触发 `babycamera_credit_reconciliation_discrepancy_total` |
| {{DATE}} | 主备切换演练 | | ☐ 通过 | Primary 不 ACK，Secondary 15min 接管 |

### T7.15 五类故障 Incident 演练（上线前必做）

> 每种场景单独填 [records/INCIDENT_DRILL_RECORD_TEMPLATE.md](./records/INCIDENT_DRILL_RECORD_TEMPLATE.md)，归档至 `docs/ops/records/`。

| 日期 | 场景 | 环境 | IC | 结果 | 记录文件 |
| --- | --- | --- | --- | --- | --- |
| {{DATE}} | AI 模型故障 | staging | | ☐ 通过 | `DRILL-INC-____-ai.md` |
| {{DATE}} | 审核厂商故障 | staging | | ☐ 通过 | `DRILL-INC-____-audit.md` |
| {{DATE}} | IAP 故障 | staging | | ☐ 通过 | `DRILL-INC-____-iap.md` |
| {{DATE}} | APNs 推送故障 | staging | | ☐ 通过 | `DRILL-INC-____-apns.md` |
| {{DATE}} | 微信 SDK 故障 | staging / 真机 | | ☐ 通过 | `DRILL-INC-____-wechat.md` |

### D1 / D7 上线后检查

| 日期 | 类型 | 检查人 | 快照脚本 | 结论 |
| --- | --- | --- | --- | --- |
| Day 1 | D1 指标检查 | | `./scripts/ops/d1-d7-metrics-snapshot.sh --day 1` | ☐ 通过 |
| Day 7 | D7 指标检查 | | `./scripts/ops/d1-d7-metrics-snapshot.sh --day 7` | ☐ 通过 |

---

## 相关文档

- **Incident 流程（T7.15）**：[INCIDENT_RESPONSE_PLAYBOOK.md](./INCIDENT_RESPONSE_PLAYBOOK.md)
- **技术止血**：[RUNBOOK.md](./RUNBOOK.md)
- **D1/D7 检查表**：[D1_D7_MONITORING_CHECKLIST.md](./D1_D7_MONITORING_CHECKLIST.md)
- **演练记录模板**：[records/INCIDENT_DRILL_RECORD_TEMPLATE.md](./records/INCIDENT_DRILL_RECORD_TEMPLATE.md)
- **指标快照脚本**：`scripts/ops/d1-d7-metrics-snapshot.sh`
- 指标契约：[METRICS_CATALOG.md](./METRICS_CATALOG.md)
- 监控基线：[infra/observability/README.md](../../infra/observability/README.md)
- 告警规则：[infra/monitoring/prometheus/alerts/babycamera-v1.yaml](../../infra/monitoring/prometheus/alerts/babycamera-v1.yaml)
- 设计阈值：[design-backend.md §11.1](../design-backend.md)
