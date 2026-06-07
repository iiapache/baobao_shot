# 三方 Mock 服务

> 任务 **T0.20** · 供 staging / 本地联调替代 Apple IAP、微信、广告联盟、内容审核、AI 模型 outbound 调用

## 快速启动

```bash
cd tests/mocks

# 仅 API Mock（P0 冒烟）
docker compose up -d mock-api

# 全部 Mock（后端 outbound 联调）
docker compose up -d
```

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

## 后端 staging 注入示例

```yaml
# values-staging.yaml（示意）
outbound:
  apple_iap_url: http://mock-iap.baobao-staging.svc:8080
  wechat_api_url: http://mock-wechat.baobao-staging.svc:8080
  ad_ssv_url: http://mock-ad.baobao-staging.svc:8080
  audit_url: http://mock-audit.baobao-staging.svc:8080
  ai_dashscope_url: http://mock-ai.baobao-staging.svc:8080
```

本地开发可将上述 URL 设为 `http://host.docker.internal:1808x`。

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
