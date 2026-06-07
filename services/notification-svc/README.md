# notification-svc

APNs 推送与设备 Token 管理（T5.7 骨架），端口 **8008**。

## 能力（T5.7）

| 组件 | 说明 |
| --- | --- |
| PostgreSQL DDL | `device_tokens` 表 + 索引（design-backend §4.1.4） |
| memory / postgres | 双后端 store factory |
| 迁移 | embed + 启动时自动 up；Makefile `migrate-up/down` |
| REST | 设备注册 / 注销、失效 Token 清理、debug 推送演示 |
| APNs stub | cn/os 双区连接池 + 可注入 `MockSender`（不连 Apple） |
| gRPC | `NotificationService.SendPush` 占位（内部调用 APNs stub） |

消息中心 / Kafka 编排见 T5.8–T5.9。

## 表结构

| 表 | 主键 / 唯一约束 | 索引 |
| --- | --- | --- |
| `device_tokens` | PK(`user_id`, `device_id`) | IDX(`apns_token`)、IDX(`user_id`) |

字段：`user_id`, `device_id`, `apns_token`, `region` (`cn`/`os`), `app_version`, `os_version`, `model`, `updated_at`。

## API

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/v1/notifications/devices` | 注册 / 更新 APNs Token（需 `Authorization` + `X-Region`） |
| DELETE | `/v1/notifications/devices/{deviceId}` | 注销设备 |
| POST | `/v1/internal/notifications/tokens/cleanup` | 失效 Token 清理（body: `{"apnsToken":"..."}`） |
| POST | `/v1/debug/apns-ping` | Mock 推送演示（`DEBUG_ENDPOINTS=true` 时启用） |
| GET | `/health` / `/ready` | 探针 |

### 注册示例

```bash
curl -s -X POST localhost:8008/v1/notifications/devices \
  -H 'Authorization: Bearer dev:usr_demo' \
  -H 'X-Region: cn' \
  -H 'Content-Type: application/json' \
  -d '{
    "deviceId": "dev_xxx",
    "apnsToken": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab",
    "appVersion": "1.0.0",
    "osVersion": "iOS 17.5",
    "model": "iPhone14,5"
  }'
```

### APNs stub 演示

```bash
curl -s -X POST localhost:8008/v1/debug/apns-ping \
  -H 'X-Region: cn' \
  -H 'Content-Type: application/json' \
  -d '{"device_token":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab","title":"T5.7","body":"APNs smoke test"}'
```

Token 以 `invalid:` 前缀模拟 Apple 410 失效，触发自动清理。

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `notification-svc` | 服务名 |
| `HTTP_PORT` | `8008` | REST 端口 |
| `GRPC_PORT` | `9008` | gRPC 端口 |
| `STORAGE_BACKEND` | `memory` | `memory` 或 `postgres` |
| `DATABASE_URL` | （空） | `STORAGE_BACKEND=postgres` 时必填 |
| `APNS_SANDBOX` | `true` | stub 池使用 sandbox host |
| `APNS_TOPIC` | `app.babycamera` | 推送 topic（gRPC SendPush） |
| `DEBUG_ENDPOINTS` | dev=`true` / prod=`false` | 是否暴露 `/v1/debug/apns-ping` |

## 命令

```bash
make build
make test
make run

# 手动迁移（需 DATABASE_URL）
make migrate-up
make migrate-down
```

## Postgres 集成测试

```bash
export TEST_DATABASE_URL='postgres://user:pass@localhost:5432/notification_test?sslmode=disable'
go test ./internal/store/ -run 'Postgres|RoundTrip' -v
```

## 参考

- [design-backend.md §4.1.4 / §8](../../docs/design-backend.md)
- [design-api.md §10](../../docs/design-api.md)
- [contracts/openapi/paths/notifications.yaml](../../contracts/openapi/paths/notifications.yaml)
