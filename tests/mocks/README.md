# 三方 Mock 服务

> 任务 **T0.20** · 供 staging / 本地联调替代 Apple IAP、微信、广告联盟、内容审核、AI 模型 outbound 调用

## 快速启动（一键）

```bash
cd tests/mocks

# 仅 API Mock（P0 冒烟）
docker compose up -d mock-api

# 全部 Mock（后端 outbound 联调 · ENV-06）
docker compose up -d

# 健康检查
../../tests/staging/verify-outbound.sh --local

# 停止
docker compose down
```

| 命令 | 启动服务 |
| --- | --- |
| `docker compose up -d mock-api` | 仅 `mock-api` :18080 |
| `docker compose up -d` | 全部 6 个 Mock（18080–18085） |
| `docker compose ps` | 查看容器状态 |

无 Docker 时可用 Python 备用服务（响应与 WireMock 映射一致）：

```bash
python3 api/mock_server.py
```

## 服务一览

| 服务 | 容器名 | 宿主机端口 | 说明 |
| --- | --- | --- | --- |
| `mock-api` | baobao-mock-api | **18080** | Baobao REST 冒烟端点（对齐 OpenAPI） |
| `mock-iap` | baobao-mock-iap | 18081 | Apple verifyReceipt / Server API 占位 |
| `mock-wechat` | baobao-mock-wechat | 18082 | 微信 oauth/token、sns/userinfo |
| `mock-ad` | baobao-mock-ad | 18083 | 穿山甲 / 优量汇 / AdMob SSV 回调 |
| `mock-audit` | baobao-mock-audit | 18084 | 阿里云 Green 图像/文本审核 |
| `mock-ai` | baobao-mock-ai | 18085 | DashScope / OpenAI 风格生成接口 |

技术栈：[WireMock](https://wiremock.org/) 3.x（`wiremock/wiremock:3.9.1`）。

## 后端 staging 注入

完整映射与 Helm values 见 [infra/staging/](../../infra/staging/)：

```yaml
# infra/staging/outbound-mapping.yaml（摘要）
outbound:
  mock-iap:    http://mock-iap.third-party-mocks.svc.cluster.local:8080      # 本地 :18081
  mock-wechat: http://mock-wechat.third-party-mocks.svc.cluster.local:8080  # 本地 :18082
  mock-ad:     http://mock-ad.third-party-mocks.svc.cluster.local:8080     # 本地 :18083
  mock-audit:  http://mock-audit.third-party-mocks.svc.cluster.local:8080  # 本地 :18084
  mock-ai:     http://mock-ai.third-party-mocks.svc.cluster.local:8080      # 本地 :18085
```

微服务 env 片段：`infra/staging/values/{auth-family,credit-sub-ad,audit,ai-dispatch}-svc.yaml`

本地开发可将上述 URL 设为 `http://host.docker.internal:1808x`（Docker Desktop）或 `http://localhost:1808x`。

## mock-api 覆盖的 OpenAPI 端点

| Method | Path | operationId |
| --- | --- | --- |
| POST | `/v1/auth/phone/code` | authPhoneSendCode |
| POST | `/v1/auth/phone/login` | authPhoneLogin |
| GET | `/v1/account/me` | accountGetMe |
| POST | `/v1/uploads/init` | uploadInit |
| POST | `/v1/uploads/complete` | uploadComplete |
| POST | `/v1/posts` | postCreate |
| GET | `/health` | — |
| GET | `/v1/ai/plays` | aiListPlays |
| POST | `/v1/ai/tasks` | aiCreateTask |
| GET | `/v1/ai/tasks/{taskId}` | aiGetTask |
| POST | `/v1/ai/tasks/{taskId}/appeal` | aiAppealTask |

映射文件：`api/mappings/`（P1: `07`–`15`；P3 AI: `16`–`33`）。

## 健康检查

```bash
curl -s http://localhost:18080/health
curl -s http://localhost:18081/__admin/health
```

## 停止

```bash
docker compose down
```

## 目录结构

```text
mocks/
├── docker-compose.yaml
├── README.md
├── api/mappings/       # Baobao REST 冒烟
├── iap/mappings/       # Apple IAP
├── wechat/mappings/    # 微信 Open API
├── ad/mappings/        # 广告联盟 SSV
├── audit/mappings/     # 内容审核
└── ai/mappings/        # AI 模型
```
