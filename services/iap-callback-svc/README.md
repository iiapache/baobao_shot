# iap-callback-svc

Apple Server Notifications v2 接收服务，解析 `REFUND` / `REVOKE` 通知并投递到 Kafka `iap.events`。

| 端口 | 8010 |
| --- | --- |
| Topic | `iap.events` |
| 下游 | `credit-sub-ad-svc` |

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `HTTP_PORT` | `8010` | HTTP 监听端口 |
| `KAFKA_BROKERS` | — | Kafka broker 列表（空则 stub producer） |
| `KAFKA_TOPIC` | `iap.events` | 发布 topic |
| `APPLE_IAP_BUNDLE_ID` | — | 可选 bundle 白名单 |

## 接口

- `POST /v1/apple/notifications` — Apple ASN v2 回调（body: `{"signedPayload":"..."}`）
- `GET /health` / `GET /ready`

## Sandbox mock

测试与本地联调可使用 mock ASN：

```
mock-asn:REFUND:{notificationUUID}:mock:{transactionId}:{productId}
```

示例：

```json
{"signedPayload":"mock-asn:REFUND:notif-001:mock:2000000123456789:credit_pack_60"}
```
