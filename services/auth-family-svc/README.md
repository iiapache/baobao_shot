# auth-family-svc

账号、家庭、宝宝档案微服务（T1.1 起：Apple ID 登录）。

## 快速启动

```bash
cd services/auth-family-svc
export SERVICE_NAME=auth-family-svc HTTP_PORT=8001 GRPC_PORT=9001
export MOCK_APPLE_VERIFY=true STORAGE_BACKEND=memory
make run
```

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `auth-family-svc` | 服务名 |
| `HTTP_PORT` | `8001` | REST 端口 |
| `GRPC_PORT` | `9001` | gRPC 端口 |
| `STORAGE_BACKEND` | `memory` | `memory` 或 `postgres` |
| `DATABASE_URL` | （空） | PostgreSQL DSN（`STORAGE_BACKEND=postgres` 时必填） |
| `MOCK_APPLE_VERIFY` | `true` | `true` 时跳过 Apple JWKS 签名校验（开发/测试） |
| `APPLE_BUNDLE_ID` | （空） | 生产 Apple `aud` 校验（T1.3+） |
| `JWT_SIGNING_SECRET` | `dev-only-change-me` | JWT 占位（T1.3 正式签发） |

## API（T1.1）

### POST /v1/auth/apple

请求头：`X-Region`、`X-App-Version`、`X-Device-Id`

```bash
curl -s localhost:8001/v1/auth/apple \
  -H 'Content-Type: application/json' \
  -H 'X-Region: cn' \
  -H 'X-App-Version: 1.0.0' \
  -H 'X-Device-Id: dev-1' \
  -d '{"identityToken":"apple-sub-demo","authorizationCode":"c-1","nickname":"豆豆妈","region":"cn"}'
```

## 数据表

见 `migrations/001_users.up.sql`（`users`：`apple_sub` 唯一、`phone+region` 唯一、`last_seen_at` 索引）。

## 测试

```bash
make test
```

单元测试使用内存 `UserStore`；生产可配合 `infra/data/docker-compose.dev.yml` 启动 PostgreSQL 并设置 `STORAGE_BACKEND=postgres`。
