# 网关限流规则（T1.12）

> 对应 [design-api.md §2.7](../../docs/design-api.md)、[design-backend.md §9.1](../../docs/design-backend.md)。

## 策略总览

| 层级 | 职责 |
| --- | --- |
| **APISIX 网关** | 首层限流 + JWT 鉴权；按路径挂载 `limit-count` |
| **微服务** | 业务维度二次限流（如 auth-family-svc 手机号滑窗） |

网关 429 响应体：

```json
{
  "code": "COMMON_RATE_LIMIT",
  "message": "rate limit exceeded"
}
```

> 网关层 429 不含 `requestId`（APISIX `limit-count` 限制）；服务层 429 含完整 design-api 字段。

## design-api §2.7 规则表

| 接口 | 维度 | 阈值 | 网关实现 | 服务实现 |
| --- | --- | --- | --- | --- |
| `POST /v1/auth/phone/code` | 手机号 + IP | 60s 内 3 次 | `limit-count` key=`$http_x_baobao_rate_phone $remote_addr` | auth-family-svc `sendLimiter` |
| `POST /v1/auth/phone/code` | 手机号 + IP | 1h 内 10 次 | 同上，双 `limit-count` 插件 | auth-family-svc `sendLimiter` hour 窗口 |
| `POST /v1/auth/phone/login` | 手机号 + IP | 60s 内 5 次 | `limit-count` key=`$http_x_baobao_rate_phone $remote_addr` | auth-family-svc `loginLimiter` |
| `POST /v1/ai/tasks` | userId | 60s 内 10 次 | 待 ai-dispatch-svc 路由（T3.x） | 服务内 |
| `POST /v1/posts` | userId | 60s 内 5 次 | 待 feed-svc 路由（T5.x） | 服务内 |
| `POST /v1/credits/sign-in` | userId | 1d 内 1 次 | 待 credit-sub-ad-svc 路由（T4.x） | 服务内 |

## 手机号提取

`POST /v1/auth/phone/*` 路由挂载 `serverless-pre-function`，从 JSON body 读取 `phone` 并写入内部头 `X-Baobao-Rate-Phone`，供 `limit-count` 组合 key 使用。

若 body 无 `phone` 字段，限流 key 退化为仅 IP（`$remote_addr` 空 phone 段）。

## 路由文件

| 文件 | 集群 |
| --- | --- |
| `routes/auth-family-api.yaml` | ack-cn dev |
| `routes/auth-family-api-os.yaml` | eks-os dev |

## 验证

```bash
# 限流：连续 4 次 code 请求应第 4 次 429
for i in 1 2 3 4; do
  curl -sS -o /dev/null -w "%{http_code}\n" -X POST \
    "https://dev-api-cn.example.com/v1/auth/phone/code" \
    -H "Content-Type: application/json" \
    -d '{"phone":"13800138000"}'
done

# 无 Token 访问受保护路由 → 401
curl -sS "https://dev-api-cn.example.com/v1/families" | jq .code
# 期望: "AUTH_TOKEN_EXPIRED"

# refresh 无需 Access Token（缺 body 返回 400，非 401）
curl -sS -o /dev/null -w "%{http_code}\n" -X POST \
  "https://dev-api-cn.example.com/v1/auth/refresh"
# 期望: 400
```

或使用 `scripts/health-check.sh --check-auth`。
