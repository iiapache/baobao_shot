# media-svc

媒体上传 STS 服务（T3.1），端口 **8003**。

## API

| 方法 | 路径 | operationId | 说明 |
| --- | --- | --- | --- |
| GET | `/health` | — | 存活探针 |
| GET | `/ready` | — | 就绪探针 |
| POST | `/v1/uploads/init` | uploadInit | 申请 OSS 直传 STS 凭据 |
| POST | `/v1/uploads/complete` | uploadComplete | 完成上传回调，写入元数据 |

### purpose 枚举

- `ai-input` → 对象前缀 `ai-tmp/<userId>/...`
- `post-item` → 对象前缀 `family/<familyId>/pending/...`（`familyId` 必填）

STS / 签名有效期默认 **600 秒**（10 分钟）。

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `media-svc` | 服务名 |
| `HTTP_PORT` | `8003` | REST 端口 |
| `GRPC_PORT` | `9003` | gRPC 端口 |
| `JWT_SIGNING_SECRET` | `dev-only-change-me` | 与 auth-family-svc 共享 |
| `STS_TTL_SECONDS` | `600` | STS 凭据有效期 |
| `STORAGE_BACKEND` | `memory` | `memory` 或 `postgres` |
| `DATABASE_URL` | （空） | `STORAGE_BACKEND=postgres` 时必填 |
| `MOCK_OSS_BASE_URL` | （空） | 本地 mock OSS PUT 基址 |
| `OSS_BUCKET` | `baby-camera-cn` | 桶名 |
| `OSS_ENDPOINT` | `https://oss-cn-hangzhou.aliyuncs.com` | OSS 端点 |

## 命令

```bash
make build
make test
make run
```

## 验证

```bash
curl -s localhost:8003/health

curl -s -X POST localhost:8003/v1/uploads/init \
  -H 'Authorization: Bearer dev:usr_demo' \
  -H 'X-Region: cn' \
  -H 'Content-Type: application/json' \
  -d '{"purpose":"ai-input","items":[{"clientRef":"c1","mime":"image/heic","size":100}]}' | jq .

curl -s -X POST localhost:8003/v1/uploads/complete \
  -H 'Authorization: Bearer dev:usr_demo' \
  -H 'Content-Type: application/json' \
  -d '{"uploadId":"<uploadId from init>"}' | jq .
```

## 参考

- [design-api.md §5](../../docs/design-api.md)
- [infra/storage/](../../infra/storage/) — OSS 前缀与 STS 策略
- [contracts/openapi/paths/uploads.yaml](../../contracts/openapi/paths/uploads.yaml)
