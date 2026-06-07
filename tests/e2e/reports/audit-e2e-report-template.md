# 内容审核 E2E 报告模板（T7.5）

> 用途：记录 CN / OS 双区域内容审核全链路抽检结果，评估 **拒绝率** 与 **误杀率** 是否达标。  
> 配套脚本：`tests/e2e/p7-audit-e2e.sh` · 参考：`docs/dev-plan.md` T7.5

---

## 1. 基本信息

| 字段 | 填写 |
| --- | --- |
| 报告编号 | AUD-E2E-YYYYMMDD-NN |
| 执行日期 | |
| 执行人 / QA | |
| 环境 | `mock` / `staging` / `preprod` |
| API Base URL | |
| Audit URL | |
| Git 分支 / Tag | |
| E2E 脚本版本 | `p7-audit-e2e.sh` |
| 断言通过数 | / 总数 |

---

## 2. 验收阈值

| 指标 | 目标 | 说明 |
| --- | --- | --- |
| 误杀率（False Positive Rate） | ≤ **5%** | 合规内容被错误拒绝的比例 |
| 漏放率（False Negative Rate） | 按合规基线记录 | 违规内容未被拦截（安全红线） |
| 入参审核 P95 | ≤ **3s** | CN 阿里云 Green / OS Rekognition |
| 出参审核 P95 | ≤ **5s** | AI 生成结果审核 |
| 申诉 SLA | ≤ **24h** | 人工复核从 `pending` 到结案 |

---

## 3. 管线覆盖清单

勾选本次报告是否覆盖：

- [ ] **入参审核（input）** — AI 任务输入图/视频
- [ ] **出参审核（output）** — AI 生成结果
- [ ] **UGC 文字（sync）** — Feed 发帖 / 评论
- [ ] **UGC 图像（async）** — Feed 媒体异步
- [ ] **UGC 视频（async）** — Feed 视频抽帧
- [ ] **AI 申诉** — `POST /v1/ai/tasks/{id}/appeal`
- [ ] **审核 job 申诉** — `POST /v1/appeals`
- [ ] **Feed UGC 申诉** — `POST /v1/e2e/feed/ugc-appeal`
- [ ] **CN 区域** — `X-Region: cn`，vendor `aliyun-green`
- [ ] **OS 区域** — `X-Region: os`，vendor Rekognition / Cloudflare / OpenAI

---

## 4. 样本统计（按区域）

### 4.1 CN（国内）

| 管线 | 样本数 | 通过 | 拒绝 | 误杀（FP） | 漏放（FN） | 备注 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| input | | | | | | |
| output | | | | | | |
| ugc-text | | | | | | |
| ugc-image | | | | | | |
| ugc-video | | | | | | |
| **小计** | | | | | | |

### 4.2 OS（海外）

| 管线 | 样本数 | 通过 | 拒绝 | 误杀（FP） | 漏放（FN） | 备注 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| input | | | | | | |
| output | | | | | | |
| ugc-text | | | | | | |
| ugc-image | | | | | | |
| ugc-video | | | | | | |
| **小计** | | | | | | |

---

## 5. 核心指标计算

```
误杀率 = 误杀样本数 (FP) / 合规样本总数 × 100%
拒绝率 = 拒绝样本数 / 总样本数 × 100%
申诉率 = 发起申诉数 / 拒绝样本数 × 100%
申诉 24h 结案率 = 24h 内结案数 / 申诉总数 × 100%
```

| 指标 | CN | OS | 合计 | 是否达标 |
| --- | ---: | ---: | ---: | --- |
| 误杀率 | % | % | % | ☐ 是 ☐ 否 |
| 拒绝率 | % | % | % | 记录 |
| 申诉率 | % | % | % | 记录 |
| 申诉 24h 结案率 | % | % | % | ☐ 是 ☐ 否 |

---

## 6. E2E 自动化结果摘要

粘贴 `p7-audit-e2e.sh` 末尾输出：

```text
[p7-audit-e2e] Results: ___ passed assertions, ___ failed
[p7-audit-e2e] P7 audit E2E PASSED: ...
```

| 检查项 | 结果 |
| --- | --- |
| `bash -n p7-audit-e2e.sh` | ☐ PASS |
| Mock 本地执行 | ☐ PASS ☐ FAIL |
| CN 全场景 | ☐ PASS |
| OS 全场景 | ☐ PASS |
| 入参 SLA ≤ 3s | ☐ PASS |
| 出参 SLA ≤ 5s | ☐ PASS |

---

## 7. 误杀案例（需人工复核）

| # | 区域 | 管线 | 样本 ID / targetRef | 误杀原因推测 | 申诉 ID | 处理结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | |
| 2 | | | | | | |

---

## 8. 漏放 / 高危案例

| # | 区域 | 管线 | 样本 ID | 违规类型 | 是否回流修复 | 跟进人 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | |

---

## 9. 申诉 SLA 跟踪

| 申诉 ID | 来源（AI / audit-job / feed） | 提交时间 | 结案时间 | 耗时 (h) | 结论 | SLA |
| --- | --- | --- | --- | ---: | --- | --- |
| | | | | | pending / upheld / overturned | ☐ ≤24h |

---

## 10. 结论与跟进

| 项 | 内容 |
| --- | --- |
| **总体结论** | ☐ 可发布 ☐ 需调策略 ☐ 阻塞 |
| **主要风险** | |
| **策略调整** | （阈值、词库、厂商场景、人工容量） |
| **下次回归日期** | |

---

## 附录：Mock 拒绝标记速查

| 区域 | 标记 | 预期 reasons |
| --- | --- | --- |
| CN | `reject_porn` | `porn` |
| CN | `reject_terror` | `terrorism` |
| CN | `reject_spam` | `antispam` |
| OS | `audit-reject-openai` | `openai_moderation:flagged` |
| OS | `audit-reject-rekognition` | `aws_rekognition:moderation_failed` |
| OS | `audit-reject-cloudflare` | `cloudflare_guard:unsafe_content` |
