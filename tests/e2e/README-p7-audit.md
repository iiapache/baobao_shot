# P7 内容审核端到端回归（T7.5）

> 流程：**入参审核 → 出参审核 → UGC（文字/图像/视频）→ 申诉**；覆盖 **CN / OS** 双区域  
> 服务：`audit-svc` · `ai-dispatch-svc` · `feed-svc` · `tests/mocks/api/mock_server.py`

## 目录

```text
tests/e2e/
├── README-p7-audit.md                          # 本文件
├── p7-audit-e2e.sh                             # API E2E shell（≥50 断言）
├── p7-audit.env.example                        # 环境变量模板（可选）
└── reports/
    └── audit-e2e-report-template.md            # 拒绝率 / 误杀率报告模板
```

## 快速开始（Mock 模式）

```bash
# 1. 启动 Mock API（含 audit CN/OS 分支）
cd tests/mocks/api && python3 mock_server.py &
# 或：cd tests/mocks && docker compose up -d mock-api

# 2. 跑 P7 审核 E2E
cd ../../e2e
chmod +x p7-audit-e2e.sh
BASE_URL=http://localhost:18080 AUDIT_URL=http://localhost:18080 ./p7-audit-e2e.sh
```

预期末尾：`P7 audit E2E PASSED: input/output/ugc CN+OS · feed · AI appeal · N assertions`。

## 双服务模式（可选）

Mock 负责 feed / AI；真实 `audit-svc` 负责同步审核：

```bash
# 终端 1：audit-svc（memory + Aliyun mock）
cd services/audit-svc && HTTP_PORT=8005 make run

# 终端 2：mock API
python3 tests/mocks/api/mock_server.py

# 终端 3：E2E
BASE_URL=http://localhost:18080 AUDIT_URL=http://localhost:8005 ./tests/e2e/p7-audit-e2e.sh
```

> `AUDIT_URL` 默认等于 `BASE_URL`。仅 mock 时二者均指向 `18080`。

## 场景矩阵

| 场景 | 管线 | 触发方式 | 预期 |
| --- | --- | --- | --- |
| A 入参通过 | input | `objectKey` 无 reject 标记 | `status=passed`，CN vendor=`aliyun-green` |
| B 入参拒绝 | input | `objectKey` 含 `reject_porn` | `status=rejected`，reasons 含 `porn` / `aws_rekognition` |
| C 出参通过 | output | 干净 `objectKey` | `result=passed`，SLA ≤ 5s |
| D 出参拒绝 | output | `reject_terror` | `status=rejected` |
| E UGC 文字通过 | ugc sync | 正常文案 | `passed` |
| F UGC 文字拒绝 | ugc sync | `reject_spam` / `违规文字` | `rejected`；feed 返回 `POST_AUDIT_REJECTED` |
| G UGC 图像异步 | ugc async | `POST /v1/audit/async` → `.../complete` | pending → passed |
| H UGC 视频异步 | ugc async | `objectKey` 含 `reject_porn` + `.mp4` | pending → rejected |
| I 审核申诉 | appeals | `POST /v1/appeals` on rejected job | `201` + `status=pending`，24h SLA |
| J AI 拒绝+申诉 | ai-dispatch | `X-E2E-Scenario: rejected` → `POST .../appeal` | `rejected` → `appealed` |
| K Feed 图文 | feed | 带 `items` 发帖 → `ugc-media-audit` | 创建 `audit` → 审核后 `published` |
| L Feed 视频下架 | feed | 视频 `reject_porn` → `ugc-media-audit` | `removed` |
| M CN / OS 双版 | 全部 | Header `X-Region: cn` / `os` | 各自 vendor 与拒绝原因 |

## Mock 拒绝标记

### CN（阿里云 Green mock）

| 标记 | 类型 | reasons |
| --- | --- | --- |
| `reject_porn` / `违规色情` | 图/视频 | `porn` |
| `reject_terror` / `违规暴恐` | 图/视频 | `terrorism` |
| `reject_spam` / `违规文字` | 文字 | `antispam` |
| 通用 `reject` | 按 mediaType | 见 `aliyun/adapter.go` mock |

### OS（Rekognition + Cloudflare + OpenAI mock）

| 标记 | 类型 | reasons |
| --- | --- | --- |
| `audit-reject-rekognition` | 图/视频 | `aws_rekognition:moderation_failed` |
| `audit-reject-cloudflare` | 图 | `cloudflare_guard:unsafe_content` |
| `audit-reject-openai` | 文字 | `openai_moderation:flagged` |
| `reject_*` 通用 | 按 mediaType | OS 组合 vendor |

## SLA 验收

| 类型 | 预算 | shell 变量 |
| --- | --- | --- |
| 入参审核 | ≤ 3s | `P7_INPUT_SLA_SEC`（默认 3） |
| 出参审核 | ≤ 5s | `P7_OUTPUT_SLA_SEC`（默认 5） |
| 申诉处理 | ≤ 24h | `P7_APPEAL_SLA_HOURS`（默认 24，报告模板填写） |

Mock 环境为秒级；staging 抽检见 `reports/audit-e2e-report-template.md`。

## API 对照

| # | 步骤 | Method | Path | 说明 |
| --- | --- | --- | --- | --- |
| 0 | 健康检查 | GET | `/health` | API + Audit |
| 1 | 登录 | POST | `/v1/auth/phone/login` | 获取 Bearer |
| 2 | 同步审核 | POST | `/v1/audit/sync` | input / output / ugc-text |
| 3 | 异步入队 | POST | `/v1/audit/async` | ugc image/video |
| 4 | 异步完成 | POST | `/v1/audit/async/{jobId}/complete` | Kafka 消费模拟 |
| 5 | 审核申诉 | POST | `/v1/appeals` | rejected job only |
| 6 | AI 申诉 | POST | `/v1/ai/tasks/{id}/appeal` | ai-dispatch 联动 |
| 7 | Feed 发帖 | POST | `/v1/posts` | 文字同步 + 媒体 audit |
| 8 | 媒体审核 | POST | `/v1/e2e/feed/ugc-media-audit` | mock 异步完成 |
| 9 | UGC 申诉 | POST | `/v1/e2e/feed/ugc-appeal` | feed 申诉 mock |

## 拒绝率 / 误杀率报告

跑完 E2E 后，按 [reports/audit-e2e-report-template.md](./reports/audit-e2e-report-template.md) 填写：

- 抽检样本数、真阳/真阴/假阳（误杀）/假阴
- CN / OS 分区统计
- 阈值：误杀率 ≤ 5%，漏放率按合规要求记录

## 关联实现

- `services/audit-svc` — 三类管线 + appeals
- `services/ai-dispatch-svc/internal/auditclient` — AI 任务申诉
- `services/feed-svc/internal/auditclient` — Feed UGC 文字同步审核
- `tests/mocks/api/mock_server.py` — P7 CN/OS 审核分支 + e2e 辅助端点

## 语法检查

```bash
bash -n tests/e2e/p7-audit-e2e.sh
```
