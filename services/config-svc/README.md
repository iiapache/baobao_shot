# config-svc

灰度配置与运营配置服务（T0.19），端口 **8009**。

## API

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/health` | 存活探针 |
| GET | `/ready` | 就绪探针 |
| GET | `/v1/config/features` | Feature flags（按 region / userIdHash 分流） |
| GET | `/v1/config/plays` | 玩法目录占位 |
| PATCH | `/v1/admin/features/{key}` | 紧急更新 flag（T7.14，`X-Admin-Token`） |
| PATCH | `/v1/admin/plays/{id}` | 紧急下架玩法目录项 |

### 分流维度

- `X-Region`（必填，`cn` / `os`）
- `X-App-Version`（可选，最低版本门槛）
- `Authorization: Bearer <jwt>`（可选，服务端计算 `userIdHash`）
- `X-User-Id-Hash`（可选，0–99，客户端预计算桶）

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `config-svc` | 服务名 |
| `HTTP_PORT` | `8009` | REST 端口 |
| `GRPC_PORT` | `9009` | gRPC 端口 |
| `CONFIG_STORAGE` | `memory` | `memory` 或 `redis`（占位） |
| `REDIS_URL` | （空） | `CONFIG_STORAGE=redis` 时必填 |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | （空） | OTLP tracing |
| `ENVIRONMENT` | `dev` | 环境标识 |
| `CONFIG_ADMIN_TOKEN` | （空） | Admin API 令牌；空则禁用 `/v1/admin/*` |

## T7.14 灰度 Flags（种子）

| Key | 默认 | 说明 |
| --- | --- | --- |
| `rollout.ai_plays_percent` | `1%` | 与 App Store Phased Release 同步的 AI 玩法放量 |
| `rollout.pricing_variant` | `control` @ 50% | 积分定价 A/B 变体 |

详见 [docs/ops/PHASED_RELEASE_PLAN.md](../../docs/ops/PHASED_RELEASE_PLAN.md)、[remote-kill-switch.sh](../../scripts/ops/remote-kill-switch.sh)。

## 命令

```bash
make build
make test
make run
```

## 验证

```bash
curl -s localhost:8009/health
curl -s -H 'X-Region: cn' -H 'X-App-Version: 1.5.0' \
  -H 'Authorization: Bearer dev' \
  localhost:8009/v1/config/features | jq .
curl -s -H 'X-Region: cn' localhost:8009/v1/config/plays | jq .
```

## 参考

- [design-backend.md §2](../../docs/design-backend.md)
- [infra/feature-flags/](../../infra/feature-flags/) — Unleash / OpenFeature 可选接入
