# ai-dispatch-svc

AI 任务编排服务（T3.6 骨架）。详见 [design-backend.md §5](../../docs/design-backend.md#5-ai-调度服务重点)。

## 能力（T3.6）

- MongoDB `ai_tasks` 集合 schema 与索引定义（§4.2）
- 任务状态机（§5.4）：`created` → `credit_held` → `input_auditing` → `queued` → `running` → `output_auditing` → `watermarking` → `succeeded`，含 `model_failed` 重试与 `failed`/`rejected`/`cancelled` 终态
- Kafka 内部队列 stub：`ai.image`、`ai.video`（`infra/messaging/kafka/topics.yaml`）
- REST：`GET /health`、`GET /ready`
- REST（T3.16）：`GET /v1/ai/plays` — 玩法目录（区域白名单、积分、视频时长档位、config-svc 灰度）
- WebSocket（T3.17）：`GET /v1/ws/ai?token=<accessToken>` — JWT 鉴权、taskIds 订阅、30s 心跳 ping/pong、任务状态 event 推送
- 内部 gRPC stub：`GetTask`（占位，待 protobuf codegen）

## 本地运行

```bash
make tidy
make run
# HTTP 8004, gRPC 9004
curl http://localhost:8004/health
```

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `HTTP_PORT` | `8004` | REST 端口 |
| `GRPC_PORT` | `9004` | gRPC 端口 |
| `STORE_BACKEND` | `memory` | `memory` / `mongo` |
| `MONGO_URI` | `mongodb://localhost:27017` | Mongo 连接串 |
| `MONGO_DATABASE` | `baobao` | 数据库名 |
| `KAFKA_ENABLED` | `false` | 启用 Kafka stub 日志 |
| `KAFKA_BROKERS` | `localhost:9092` | broker 列表（逗号分隔） |
| `JWT_SIGNING_SECRET` | `dev-only-change-me` | 与 auth-family-svc 共享 |
| `CONFIG_SVC_URL` | `` | config-svc 基址；空则使用内存灰度 stub |
| `WS_PING_INTERVAL_SECS` | `30` | WebSocket 心跳间隔 |
| `WS_PONG_TIMEOUT_SECS` | `60` | 无 pong 超时断开 |

## 测试

```bash
make test
```
