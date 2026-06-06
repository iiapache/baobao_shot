# P0 冒烟脚本

> 流程：**登录 → 拍照(mock) → 发布(mock)**  
> 契约：[contracts/openapi/openapi.yaml](../../contracts/openapi/openapi.yaml)

## 前置

- `curl`（必需）
- `jq`（可选，用于解析 JSON）
- Docker（mock 模式）

## Mock 模式（推荐 P0 验收）

```bash
cd tests/mocks && docker compose up -d mock-api
cd ../smoke
cp smoke.env.example smoke.env   # 可选
chmod +x smoke.sh
./smoke.sh
```

## Staging 模式

```bash
export BASE_URL=https://staging-api-cn.example.com
export STAGING_RESOLVE="staging-api-cn.example.com:443:<LB-IP>"
export SMOKE_PHONE=13800138001
export SMOKE_CODE=<真实验证码>
./smoke.sh
```

## Postman

导入 [baobao-p0-smoke.postman_collection.json](./baobao-p0-smoke.postman_collection.json)，设置 collection 变量：

| 变量 | 默认值 |
| --- | --- |
| `baseUrl` | `http://localhost:18080` |
| `region` | `cn` |
| `appVersion` | `1.0.0-staging` |
| `deviceId` | `qa-device-iphone12-001` |
| `phone` | `13800138001` |
| `code` | `123456` |

运行顺序：Folder **P0 Smoke** → Run collection。

## 步骤与 OpenAPI operationId

| # | 步骤 | Method | Path | operationId |
| --- | --- | --- | --- | --- |
| 0 | 健康检查 | GET | `/health` | — |
| 1 | 发送验证码 | POST | `/v1/auth/phone/code` | authPhoneSendCode |
| 2 | 登录 | POST | `/v1/auth/phone/login` | authPhoneLogin |
| 3 | 申请上传 | POST | `/v1/uploads/init` | uploadInit |
| 4 | Mock OSS 直传 | PUT | mock uploadUrl | — |
| 5 | 完成上传 | POST | `/v1/uploads/complete` | uploadComplete |
| 6 | 发布 | POST | `/v1/posts` | postCreate |

## 预期结果

- 全部步骤 HTTP 200
- 响应体 `code` 为 `OK`（ApiResponse 契约）
- 最终获得 `postId`
