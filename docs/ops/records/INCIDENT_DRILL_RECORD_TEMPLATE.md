# 五类故障 Incident 演练记录（T7.15）

> 复制本文件为 `docs/ops/records/DRILL-INC-YYYYMMDD-{scenario}.md` 并填写。  
> 关联流程：[INCIDENT_RESPONSE_PLAYBOOK.md](../INCIDENT_RESPONSE_PLAYBOOK.md)  
> 技术参考：[RUNBOOK.md](../RUNBOOK.md)  
> 值班表：[ONCALL_ROSTER_TEMPLATE.md](../ONCALL_ROSTER_TEMPLATE.md)

---

## 基本信息

| 字段 | 值 |
| --- | --- |
| 演练编号 | DRILL-INC-________ |
| Incident ID（演练用） | INC-________ |
| 演练日期 | YYYY-MM-DD |
| 演练环境 | ☐ staging　☐ tabletop only |
| 故障场景 | ☐ AI 模型　☐ 审核厂商　☐ IAP　☐ APNs 推送　☐ 微信 SDK |
| 演练类型 | ☐ 注入故障　☐ tabletop　☐ 告警路由测试 |
| Incident Commander | ____________ |
| Technical Lead | ____________ |
| 观察员 | ____________ |

---

## 参与人员

| 角色 | 姓名 | 签到 |
| --- | --- | --- |
| 主值班（IC） | | ☐ |
| 副值班 | | ☐ |
| AI / Backend / Commerce TL | | ☐ |
| Compliance（审核场景必填） | | ☐ |
| SRE / INFRA | | ☐ |

---

## 前置条件

| # | 检查项 | 通过 |
| --- | --- | --- |
| 1 | On-call 表当周已填写 | ☐ |
| 2 | 钉钉 / 飞书 / 电话 webhook 可用 | ☐ |
| 3 | Grafana `babycamera-v1-overview` 可访问 | ☐ |
| 4 | RUNBOOK + INCIDENT_PLAYBOOK 已分发 | ☐ |
| 5 | 注入工具 / mock 端点就绪 | ☐ |

---

## 场景定义

**模拟故障描述：**

> （例：staging ai-dispatch mock adapter 返回 100% 503，持续 15 分钟）

**预期影响：**

> （用户可见症状、影响区域、是否 P0）

**注入步骤：**

```bash
# 粘贴实际执行的注入命令
```

**注入开始时间 (UTC)：** ____________  
**注入结束时间 (UTC)：** ____________

---

## Incident 流程验收

| # | 验收项 | SLA / 标准 | 实测 | 通过 |
| --- | --- | --- | --- | --- |
| 1 | 告警触发 | 注入后 ≤ 10 min | ___ min | ☐ |
| 2 | 主值班 ACK | ≤ **15 min**（P0） | ___ min | ☐ |
| 3 | 定级正确 | P0/P1 与场景匹配 | | ☐ |
| 4 | 拉对 Technical Lead | `team` 标签正确 | | ☐ |
| 5 | 首次状态更新 | ACK 后 ≤ 15 min | | ☐ |
| 6 | 止血动作执行 | 按 PLAYBOOK §5.x | | ☐ |
| 7 | RUNBOOK 命令可执行 | 无 block | | ☐ |
| 8 | 指标 / E2E 验证 | 恢复至阈值 | | ☐ |
| 9 | Resolved 公告 | 模板完整 | | ☐ |
| 10 | Escalation（可选） | Primary 不 ACK → Secondary 15min | | ☐ |

---

## 场景专项 checklist

### AI 模型

| 项 | 通过 |
| --- | --- |
| 远端下架故障 `style` | ☐ |
| 备用 adapter 切换或回滚 | ☐ |
| AI 成功率恢复 ≥ 95% | ☐ |

### 审核厂商

| 项 | 通过 |
| --- | --- |
| Compliance 已介入评估 | ☐ |
| 未 unauthorized fail-open | ☐ |
| UGC 入口暂停（如适用） | ☐ |

### IAP

| 项 | 通过 |
| --- | --- |
| Apple 状态已查 | ☐ |
| 促销入口暂停 | ☐ |
| 客服口径已同步 | ☐ |

### APNs

| 项 | 通过 |
| --- | --- |
| 证书 / Vault 检查 | ☐ |
| 非关键推送降频 | ☐ |
| 互动推送 E2E 恢复 | ☐ |

### 微信 SDK

| 项 | 通过 |
| --- | --- |
| 系统分享兜底验证 | ☐ |
| 远端隐藏微信按钮（如适用） | ☐ |
| Universal Link 诊断 | ☐ |

---

## 时间线

| 时间 (UTC) | 事件 | 负责人 |
| --- | --- | --- |
| | 注入开始 | |
| | 告警 firing | |
| | ACK | |
| | 止血开始 | |
| | 服务恢复 | |
| | Resolved 公告 | |
| | 注入撤销 | |

---

## 沟通记录

| 渠道 | 是否测试 | 延迟 | 备注 |
| --- | --- | --- | --- |
| 钉钉 | ☐ | | |
| 飞书 | ☐ | | |
| 电话（P0） | ☐ | | |

**ACK 消息截图 / 链接：** ____________

---

## 问题与改进

| # | 问题描述 | 严重度 | 负责人 | ticket |
| --- | --- | --- | --- | --- |
| 1 | | P0/P1/P2 | | |
| 2 | | | | |

---

## 演练结论

| 项 | 选择 |
| --- | --- |
| 总体结论 | ☐ 通过　☐ 有条件通过　☐ 未通过 |
| Incident 流程 SLA | ☐ 达标　☐ 未达标 |
| 五类场景累计 | ☐ 5/5 已完成　☐ 进行中（___/5） |

**未通过原因：**

> （填写）

---

## 签字确认

| 角色 | 姓名 | 日期 |
| --- | --- | --- |
| Incident Commander | | |
| SRE Lead | | |
| QA Owner（T7.15） | | |
