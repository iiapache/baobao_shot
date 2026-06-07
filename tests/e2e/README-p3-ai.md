# P3 AI 端到端回归（T3.26）

> 流程：**登录 → 玩法目录 → 上传 → 提交任务 → 轮询/WebSocket → 失败/拒绝/申诉 → 视频 5s/10s**  
> 服务：`ai-dispatch-svc` · 契约：[contracts/openapi/paths/ai.yaml](../../contracts/openapi/paths/ai.yaml)

## 目录

```text
tests/e2e/
├── README-p3-ai.md                          # 本文件
├── p3-e2e.sh                                # API E2E shell（mock / staging）
├── p3-ai.env.example                        # P3 环境变量模板
├── baobao-p3-ai-e2e.postman_collection.json # Postman / Newman 集合
└── ios/
    └── P3AIPlayMockMapping.md               # iOS 单元测试 ↔ mock 场景映射
```

## 快速开始（Mock 模式）

```bash
# 1. 启动 Mock API
cd tests/mocks && docker compose up -d mock-api
# 无 Docker：python3 api/mock_server.py

# 2. 跑 P3 AI E2E
cd ../e2e && chmod +x p3-e2e.sh && ./p3-e2e.sh
```

预期末尾：`P3 AI E2E PASSED: image happy · model_failed · rejected+appeal · video 5s/10s · slow · background`。

## Postman / Newman

导入 [baobao-p3-ai-e2e.postman_collection.json](./baobao-p3-ai-e2e.postman_collection.json)，运行 Folder **P3 AI E2E**。

```bash
npx --yes newman run tests/e2e/baobao-p3-ai-e2e.postman_collection.json \
  --env-var baseUrl=http://localhost:18080
```

## 场景与 Mock 触发

| 场景 | 触发方式 | 预期 taskId | 终态 |
| --- | --- | --- | --- |
| A 图像 happy | `play=ghibli_kid` | `tsk_e2e_img_happy` | `succeeded` + `resultUrl` + `deepSynth` |
| B ModelFailed | Header `X-E2E-Scenario: model_failed` | `tsk_e2e_model_failed` | `failed` + 积分退还提示 |
| C Rejected + 申诉 | Header `X-E2E-Scenario: rejected` → `POST .../appeal` | `tsk_e2e_rejected` | `rejected` → `appealed` |
| D 视频 5s | `play=video_walk` + `params.duration=5` | `tsk_e2e_vid_5s` | `succeeded` + `.mp4` |
| E 视频 10s | `play=video_walk` + `params.duration=10` | `tsk_e2e_vid_10s` | `succeeded` + `.mp4` |
| F 弱网 mock | Header `X-E2E-Network: slow` | `tsk_e2e_slow_net` | 多轮 `running` → `succeeded` |
| G 切后台 mock | Header `X-E2E-Scenario: background` | `tsk_e2e_background` | 创建即 `running` → 轮询 `succeeded` |

WireMock 弱网场景使用 `scenarioName: ai_slow_network_poll`（映射 `29`–`31`）。Python fallback 使用内存轮询计数。

## SLA 验收（T3.26）

| 类型 | P95 预算 | shell 校验 |
| --- | --- | --- |
| 图像 | ≤ 60s | `P3_IMAGE_SLA_SEC`（默认 60） |
| 视频 | ≤ 5min（300s） | `P3_VIDEO_SLA_SEC`（默认 300） |

Mock 环境下链路为秒级；staging 压测见 T7.6。

## 步骤与 OpenAPI operationId

| # | 步骤 | Method | Path | operationId |
| --- | --- | --- | --- | --- |
| 0 | 健康检查 | GET | `/health` | — |
| 1 | 登录 | POST | `/v1/auth/phone/login` | authPhoneLogin |
| 2 | 玩法目录 | GET | `/v1/ai/plays` | aiListPlays |
| 3 | AI 输入上传 | POST | `/v1/uploads/init` | uploadInit |
| A | 提交图像任务 | POST | `/v1/ai/tasks` | aiCreateTask |
| A | 查询任务 | GET | `/v1/ai/tasks/{taskId}` | aiGetTask |
| C | 申诉 | POST | `/v1/ai/tasks/{taskId}/appeal` | aiAppealTask |

## 关联 Mock 映射

P3 新增 WireMock 映射：`tests/mocks/api/mappings/16-*.json` … `33-*.json`。  
Python fallback：`tests/mocks/api/mock_server.py`（含 `AI_TASKS` 状态机）。

## 单元 / 包测试（补充验证）

```bash
# ai-dispatch-svc（状态机、申诉、worker 超时）
cd services/ai-dispatch-svc && go test ./...

# iOS AIPlay 包（Coordinator 弱网/后台/失败态）
cd ios/Packages/BabyCameraAIPlay && swift test
```

端侧弱网/切后台详细映射见 [ios/P3AIPlayMockMapping.md](./ios/P3AIPlayMockMapping.md)。

## Staging 模式

```bash
export BASE_URL=https://staging-api-cn.example.com
export STAGING_RESOLVE="staging-api-cn.example.com:443:<LB-IP>"
export E2E_ADMIN_CODE=<真实验证码>
./p3-e2e.sh
```

> Staging 需真实 AI 链路；Mock 专用 Header（`X-E2E-Scenario`）在 staging 可能被忽略。

## 验收对照（T3.26）

| 验收项 | 实现 |
| --- | --- |
| 图像 happy path | `p3-e2e.sh` Scenario A |
| ModelFailed + 积分退还 | Scenario B |
| Rejected + 申诉 | Scenario C + 映射 `27-ai-task-appeal.json` |
| 视频 5s / 10s | Scenario D / E |
| 弱网 / 切后台 mock | Scenario F / G + iOS 单元测试映射 |
| P95 SLA 断言 | `assert_sla`（图 60s / 视频 300s） |
| Postman 集合 | `baobao-p3-ai-e2e.postman_collection.json` |

## 相关任务

- T3.15：申诉接口
- T3.16：玩法目录
- T3.22–T3.25：iOS AIPlay 全链路
- T3.26：本目录
