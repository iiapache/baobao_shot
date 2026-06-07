# 宝宝成长相机 详细设计：接口契约

> 端 ↔ 后端 REST + WebSocket 契约文档。本文不重复服务内部实现，详细服务内部见 [design-backend.md](./design-backend.md)。

---

## 1. 文档信息

| 项目 | 内容 |
| --- | --- |
| 文档名称 | 宝宝成长相机 · 详细设计 · 接口契约 |
| 文档版本 | v0.1 |
| API 版本 | v1 |
| 最近更新 | 2026-06-05 |
| 关联文档 | [PRD.md](./PRD.md)、[PRD-决策记录.md](./PRD-%E5%86%B3%E7%AD%96%E8%AE%B0%E5%BD%95.md)、[design.md](./design.md)、[design-ios.md](./design-ios.md)、[design-backend.md](./design-backend.md) |

### 1.1 与 PRD / 决策记录映射

| 本文章节 | 对应 PRD | 对应决策 |
| --- | --- | --- |
| §3 鉴权与账号 | §4.1 | D1 |
| §4 家庭与宝宝 | §4.1、§4.2 | D1 |
| §5 媒体上传 | §4.13、§9 | D2、D3 |
| §6 AI 任务 | §4.5、§4.6 | D8 |
| §7 家庭圈 | §4.9 | D3 |
| §8 积分 / 订阅 / 广告 | §4.11 | D9 |
| §9 智能文案 | §4.10 | D5 |
| §10 通知 | §4.12 | - |
| §11 备份凭据 | §4.13 | D2 |
| §12 错误码 | 全 | - |

---

## 2. 通用约定

### 2.1 BaseURL

| 区域 | REST | WebSocket |
| --- | --- | --- |
| 中国 | `https://api-cn.babygrowth.app` | `wss://ws-cn.babygrowth.app` |
| 海外 | `https://api-os.babygrowth.app` | `wss://ws-os.babygrowth.app` |

### 2.2 请求头

| Header | 必填 | 说明 |
| --- | :---: | --- |
| `Authorization: Bearer <token>` | 鉴权接口外必填 | Access Token |
| `X-Region` | 是 | `cn` / `os` |
| `X-App-Version` | 是 | 形如 `1.0.0` |
| `X-Device-Id` | 是 | IDFV 或自生成稳定 ID |
| `X-Trace-Id` | 否 | 客户端生成的 trace id（透传链路） |
| `Idempotency-Key` | 写接口建议 | UUID，60s 内同 key 同响应 |
| `Content-Type` | 是 | `application/json; charset=utf-8` |
| `Accept-Language` | 否 | `zh-CN` / `en` |

### 2.3 统一响应体

```json
{
  "code": "OK",
  "message": "ok",
  "requestId": "req_01HZX...",
  "data": { }
}
```

- `code` 为字符串错误码（详见 §12）。
- `message` 仅给开发者排查用，客户端展示需根据 `code` 走本地化文案。
- `data` 为业务数据；列表接口在 `data` 内含 `items` 与 `nextCursor`。

### 2.4 分页约定

- 游标分页：`?cursor=<opaque>&limit=20`，`limit` 默认 20，上限 50。
- 服务端返回 `nextCursor`（无更多则 `null`）。
- 时间倒序场景默认按 `createdAt DESC`。

### 2.5 错误响应

```json
{
  "code": "AUTH_TOKEN_EXPIRED",
  "message": "access token expired",
  "requestId": "req_01HZX..."
}
```

HTTP 状态码与 `code` 配合使用：

- `200 OK` 成功
- `400 Bad Request` 参数错误（`COMMON_BAD_PARAM`）
- `401 Unauthorized` 鉴权失效
- `403 Forbidden` 权限不足
- `404 Not Found` 资源不存在
- `409 Conflict` 幂等冲突 / 状态不允许
- `422 Unprocessable` 业务校验未通过
- `429 Too Many Requests` 限流
- `5xx` 服务异常

### 2.6 签名与防重放（敏感接口）

- 适用接口：`/v1/credits/iap-verify`、`/v1/credits/ad-reward`、`/v1/families/*/takeover`、`/v1/account`（DELETE）。
- 请求头额外携带 `X-Nonce`（每次请求唯一） + `X-Timestamp`（毫秒，与服务器允许 ±5min 偏差）。
- 服务端用 Nonce 缓存 10 分钟，防重放。

### 2.7 限流

| 接口 | 维度 | 阈值 |
| --- | --- | --- |
| `POST /v1/auth/phone/code` | 手机号 + IP | 60s 内 3 次，1h 内 10 次 |
| `POST /v1/auth/phone/login` | 手机号 + IP | 60s 内 5 次 |
| `POST /v1/ai/tasks` | userId | 60s 内 10 次 |
| `POST /v1/posts` | userId | 60s 内 5 次 |
| `POST /v1/credits/sign-in` | userId | 1d 内 1 次 |

---

## 3. 鉴权与账号

### 3.1 接口清单

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/auth/apple` | Apple ID 登录 / 注册 |
| POST | `/v1/auth/phone/code` | 发送短信验证码（仅中国区） |
| POST | `/v1/auth/phone/login` | 手机号 + 验证码登录 / 注册 |
| POST | `/v1/auth/refresh` | 刷新 Access Token（Refresh Rotation） |
| POST | `/v1/account/logout` | 主动登出（撤销当前会话） |
| GET | `/v1/account/me` | 获取当前用户基本信息 |
| PATCH | `/v1/account/me` | 更新昵称 / 头像 |
| GET | `/v1/account/consents/child-data` | 查询同意状态（含 `currentVersion` / `requiresConsent`） |
| POST | `/v1/account/consents/child-data` | 提交监护人同意（版本号 `child_consent_v1`） |
| DELETE | `/v1/account` | 注销账号（异步处理 + 软删 + 7 天可撤销） |

### 3.2 请求 / 响应示例：`POST /v1/auth/apple`

请求：

```json
{
  "identityToken": "eyJraWQ...",
  "authorizationCode": "c-1234567890",
  "nickname": "豆豆妈",
  "region": "cn"
}
```

响应：

```json
{
  "code": "OK",
  "requestId": "req_...",
  "data": {
    "userId": "usr_01HZ...",
    "isNewUser": true,
    "accessToken": "eyJhbGciOi...",
    "accessTokenExpiresIn": 3600,
    "refreshToken": "eyJhbGciOi...",
    "refreshTokenExpiresIn": 2592000,
    "profile": {
      "nickname": "豆豆妈",
      "avatarUrl": null,
      "region": "cn",
      "consents": { "childData": false }
    }
  }
}
```

---

## 4. 家庭与宝宝

### 4.1 家庭

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/families` | 创建家庭 |
| GET | `/v1/families` | 获取我加入的家庭列表 |
| GET | `/v1/families/{familyId}` | 家庭详情（含成员、宝宝） |
| PATCH | `/v1/families/{familyId}` | 修改家庭名称 |
| DELETE | `/v1/families/{familyId}` | 解散家庭（管理员） |
| POST | `/v1/families/{familyId}/invitations` | 生成邀请码 |
| DELETE | `/v1/families/{familyId}/invitations/{code}` | 立即作废邀请码 |
| POST | `/v1/invitations/{code}/join` | 通过邀请码加入家庭 |
| POST | `/v1/families/{familyId}/transfer` | 主动转让管理员 |
| POST | `/v1/families/{familyId}/takeover` | 发起 / 投票失联接管 |
| GET | `/v1/families/{familyId}/members` | 成员列表 |
| PATCH | `/v1/families/{familyId}/members/{userId}` | 修改成员角色 / 备注 |
| DELETE | `/v1/families/{familyId}/members/{userId}` | 移除成员 |

### 4.2 宝宝档案

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/families/{familyId}/babies` | 创建宝宝档案 |
| GET | `/v1/families/{familyId}/babies` | 获取家庭的宝宝列表 |
| GET | `/v1/babies/{babyId}` | 宝宝详情 |
| PATCH | `/v1/babies/{babyId}` | 修改宝宝档案 |
| DELETE | `/v1/babies/{babyId}` | 删除宝宝档案（软删） |
| POST | `/v1/babies/{babyId}/milestones` | 添加自定义里程碑 |
| GET | `/v1/babies/{babyId}/milestones` | 获取里程碑列表（含内置 + 自定义） |

### 4.3 请求 / 响应示例：`POST /v1/invitations/{code}/join`

请求：

```json
{
  "relation": "grandma",
  "nickname": "外婆"
}
```

响应：

```json
{
  "code": "OK",
  "requestId": "req_...",
  "data": {
    "familyId": "fam_01HZ...",
    "role": "family",
    "joinedAt": "2026-06-05T10:00:00Z"
  }
}
```

错误示例（已达上限）：

```json
{
  "code": "FAMILY_MEMBER_LIMIT",
  "message": "family member limit reached",
  "requestId": "req_..."
}
```

---

## 5. 媒体上传（仅服务于"已发布作品"与 AI 临时输入）

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/uploads/init` | 申请 OSS 直传凭据（含 STS Token、object key 模板） |
| POST | `/v1/uploads/complete` | 完成上传回调（写元数据 / 进入审核队列） |

> 端侧拿到 STS 凭据后直接 PUT 到 OSS，原图绝不经过业务服务器。AI 任务输入图与发布作品文件复用同一套上传链路，仅 `purpose` 字段不同。

### 5.1 请求示例：`POST /v1/uploads/init`

```json
{
  "purpose": "ai-input",          // ai-input | post-item
  "items": [
    { "clientRef": "c1", "kind": "image", "mime": "image/heic", "size": 2400000, "sha256": "abc..." }
  ],
  "familyId": "fam_01HZ..."        // post-item 必填
}
```

响应：

```json
{
  "code": "OK",
  "data": {
    "uploads": [
      {
        "clientRef": "c1",
        "objectKey": "ai-tmp/usr_.../tsk-pending-c1.heic",
        "url": "https://oss-cn-...",
        "method": "PUT",
        "headers": { "Content-Type": "image/heic" },
        "expiresIn": 600
      }
    ]
  }
}
```

---

## 6. AI 任务

### 6.1 接口清单

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/v1/ai/plays` | 玩法目录（含当前区域可用项、所需积分） |
| POST | `/v1/ai/tasks` | 提交 AI 任务（图像 / 视频） |
| GET | `/v1/ai/tasks/{taskId}` | 查询任务 |
| GET | `/v1/ai/tasks` | 用户 AI 任务历史（分页） |
| POST | `/v1/ai/tasks/{taskId}/cancel` | 取消（仅 created/credit_held/input_auditing 状态） |
| POST | `/v1/ai/tasks/{taskId}/appeal` | 申诉（仅 rejected） |

### 6.2 请求 / 响应示例：`POST /v1/ai/tasks`

请求：

```json
{
  "play": "ghibli_kid",
  "inputObjectKey": "ai-tmp/usr_.../c1.heic",
  "params": {
    "duration": 0,            // 仅视频玩法填，秒
    "aspectRatio": "1:1"
  },
  "familyId": "fam_01HZ..."   // 用于权限校验
}
```

响应：

```json
{
  "code": "OK",
  "data": {
    "taskId": "tsk_01HZ...",
    "state": "credit_held",
    "costCredits": 8,
    "balanceAfter": 92,
    "estimatedSeconds": 18
  }
}
```

可能错误：

| 错误码 | 含义 |
| --- | --- |
| `AI_INSUFFICIENT_CREDIT` | 积分不足 |
| `AI_PLAY_NOT_AVAILABLE` | 玩法在当前区域 / 版本不可用 |
| `AI_INPUT_NOT_FOUND` | 输入对象不存在或过期 |
| `AI_RATE_LIMITED` | 提交过频 |

### 6.3 WebSocket：`/v1/ws/ai`

连接：`wss://ws-cn.babygrowth.app/v1/ws/ai?token=<accessToken>`

订阅消息（客户端 → 服务端）：

```json
{ "op": "subscribe", "taskIds": ["tsk_01HZ...", "tsk_01HZ..."] }
```

事件消息（服务端 → 客户端）：

```json
{
  "op": "event",
  "taskId": "tsk_01HZ...",
  "state": "succeeded",
  "resultUrl": "https://cdn-cn.babygrowth.app/ai-out/usr_.../tsk_01HZ....heic",
  "thumbnailUrl": "https://cdn-cn.babygrowth.app/ai-out/usr_.../tsk_01HZ...-thumb.jpg",
  "deepSynth": { "watermark": "v1", "manifest": "c2pa-v1" },
  "costCredits": 8,
  "balanceAfter": 92
}
```

心跳：服务端每 30s 发 `{"op":"ping"}`，客户端回 `{"op":"pong"}`，60s 无任何消息客户端主动重连。

---

## 7. 家庭圈

### 7.1 接口清单

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/posts` | 发布作品 |
| GET | `/v1/posts/{postId}` | 作品详情 |
| DELETE | `/v1/posts/{postId}` | 撤回发布（OSS 异步清理） |
| GET | `/v1/feeds/family` | 家庭 Feed（按 familyId 过滤） |
| POST | `/v1/posts/{postId}/likes` | 点赞 |
| DELETE | `/v1/posts/{postId}/likes` | 取消点赞 |
| POST | `/v1/posts/{postId}/comments` | 评论 |
| DELETE | `/v1/posts/{postId}/comments/{commentId}` | 删评论 |
| GET | `/v1/posts/{postId}/comments` | 评论分页 |

### 7.2 请求示例：`POST /v1/posts`

```json
{
  "familyId": "fam_01HZ...",
  "babyIds": ["bb_01HZ..."],
  "caption": "豆豆 · 第 312 天 · 吉卜力风",
  "visibility": "family",
  "items": [
    { "kind": "image", "objectKey": "family/fam_.../post/.../1.heic", "width": 1024, "height": 1024, "deepSynth": true },
    { "kind": "image", "objectKey": "family/fam_.../post/.../2.heic", "width": 1024, "height": 1024, "deepSynth": false }
  ]
}
```

响应：

```json
{
  "code": "OK",
  "data": {
    "postId": "pst_01HZ...",
    "status": "published",
    "createdAt": "2026-06-05T10:00:00Z"
  }
}
```

可能错误：

| 错误码 | 含义 |
| --- | --- |
| `POST_ITEM_LIMIT` | 单次最多 9 张 + 1 视频 |
| `POST_AUDIT_REJECTED` | UGC 文字命中违规词 |
| `POST_FAMILY_FORBIDDEN` | 无该家庭发布权限（访客） |

---

## 8. 积分 / 订阅 / 广告

### 8.1 积分

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/v1/credits/balance` | 当前余额 |
| GET | `/v1/credits/transactions` | 账本流水（分页） |
| POST | `/v1/credits/sign-in` | 每日签到 |
| POST | `/v1/credits/ad-reward` | 激励广告回调（端侧观看完毕后上报；同时广告联盟服务端回调走单独路由） |
| POST | `/v1/credits/iap-verify` | IAP 充值校验（StoreKit 2 JWS） |
| GET | `/v1/credits/rates` | 各玩法当前积分单价（用于端侧展示） |

### 8.2 订阅

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/v1/subscriptions/me` | 当前订阅状态与权益 |
| POST | `/v1/subscriptions/iap-verify` | 订阅 IAP 校验 |
| GET | `/v1/subscriptions/products` | SKU 列表（中国 / 海外） |

### 8.3 请求示例：`POST /v1/credits/iap-verify`

请求：

```json
{
  "transactionId": "2000000123456789",
  "signedTransaction": "eyJhbGciOi...",
  "productId": "credit_pack_330"
}
```

响应（首次校验成功）：

```json
{
  "code": "OK",
  "data": {
    "grantedCredits": 330,
    "balanceAfter": 422,
    "transactionId": "2000000123456789",
    "ledgerId": "led_01HZ..."
  }
}
```

幂等情况（同 transactionId 重复上送）：

```json
{
  "code": "OK",
  "data": {
    "grantedCredits": 0,
    "balanceAfter": 422,
    "transactionId": "2000000123456789",
    "ledgerId": "led_01HZ...",
    "duplicate": true
  }
}
```

可能错误：

| 错误码 | 含义 |
| --- | --- |
| `IAP_VERIFY_FAILED` | JWS 校验失败 |
| `IAP_PRODUCT_MISMATCH` | productId 与历史记录不符 |
| `IAP_USER_MISMATCH` | transactionId 已绑定其他用户 |

---

## 9. 智能文案

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/caption/generate` | 生成 3 条候选文案（免费，每日 50 次/账号） |

请求：

```json
{
  "babyId": "bb_01HZ...",
  "ageDays": 312,
  "play": "ghibli_kid",
  "location": "杭州"
}
```

响应：

```json
{
  "code": "OK",
  "data": {
    "candidates": [
      { "text": "豆豆 · 第 312 天 · 化身吉卜力小主角 🌿", "hashtags": ["#宝宝成长", "#吉卜力"] },
      { "text": "杭州的小晴天里，第 312 天的豆豆 ✨", "hashtags": ["#日常打卡"] },
      { "text": "AI 帮我画了一个童话版的豆豆 💫", "hashtags": ["#AI共创"] }
    ],
    "remainingToday": 49
  }
}
```

错误：

- `CAPTION_DAILY_LIMIT`：超出每日额度。

---

## 10. 通知

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/notifications/devices` | 注册 / 更新 APNs Token |
| DELETE | `/v1/notifications/devices/{deviceId}` | 注销设备（登出 / 卸载提示触发） |
| GET | `/v1/notifications` | 消息中心分页 |
| POST | `/v1/notifications/mark-read` | 标记为已读（可批量） |
| GET | `/v1/notifications/subscriptions` | 类目订阅状态 |
| PATCH | `/v1/notifications/subscriptions` | 修改类目订阅 |

请求示例：`POST /v1/notifications/devices`

```json
{
  "deviceId": "dev_xxx",
  "apnsToken": "ab12...",
  "appVersion": "1.0.0",
  "osVersion": "iOS 17.5",
  "model": "iPhone14,5"
}
```

---

## 11. 备份凭据

> 仅托管 OAuth Token / 配置元数据。文件传输走对应云盘 SDK，不经过业务服务器。

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/backup/providers` | 绑定备份目标（iCloud / 百度网盘 / Photos） |
| GET | `/v1/backup/providers` | 当前已绑定列表 |
| DELETE | `/v1/backup/providers/{id}` | 解绑 |
| GET | `/v1/backup/status` | 总体备份状态（最近一次时间、失败次数） |
| POST | `/v1/backup/status` | 端侧上报最近一次备份结果 |

---

## 12. 错误码（统一）

> 错误码按业务域分段；客户端必须按 `code` 走文案与跳转，禁止直接展示 `message`。

| 段位 | 业务域 | 备注 |
| --- | --- | --- |
| `COMMON_*` | 通用 | 参数 / 资源 / 限流 / 内部错误 |
| `AUTH_*` | 鉴权 | Token、登录、注销 |
| `ACCOUNT_*` | 账号 | 用户档案、同意书、注销 |
| `FAMILY_*` | 家庭 | 家庭组、邀请、成员、转让、接管 |
| `BABY_*` | 宝宝档案 | |
| `UPLOAD_*` | 媒体上传 | OSS 直传相关 |
| `AI_*` | AI 任务 | 提交、状态、申诉 |
| `POST_*` | 家庭圈 | 发布、点赞、评论 |
| `CREDIT_*` | 积分 | 余额、签到、激励 |
| `IAP_*` | IAP 充值 / 订阅 | StoreKit 校验 |
| `SUB_*` | 订阅 | 状态、权益 |
| `AUDIT_*` | 审核 | 入参 / 出参 / UGC |
| `BACKUP_*` | 备份 | 绑定、凭据 |
| `NOTIF_*` | 通知 | 设备、类目 |
| `CAPTION_*` | 文案 | 限额 |
| `SYS_*` | 系统 | 5xx |

### 12.1 关键错误码示例

| 错误码 | HTTP | 含义 | 客户端建议 |
| --- | --- | --- | --- |
| `COMMON_BAD_PARAM` | 400 | 参数不合法 | 表单校验提示 |
| `COMMON_RATE_LIMIT` | 429 | 限流 | 退避后重试 |
| `COMMON_FORBIDDEN` | 403 | 权限不足 | 不可重试 |
| `COMMON_NOT_FOUND` | 404 | 资源不存在 | - |
| `AUTH_TOKEN_EXPIRED` | 401 | Access 过期 | 调 `/auth/refresh` |
| `AUTH_REFRESH_INVALID` | 401 | Refresh 失效 | 重新登录 |
| `AUTH_DEVICE_MISMATCH` | 401 | 设备绑定不一致 | 重新登录 |
| `ACCOUNT_CONSENT_REQUIRED` | 422 | 缺监护人同意 | 引导到同意书 |
| `FAMILY_INVITE_EXPIRED` | 410 | 邀请码过期 | 让管理员重发 |
| `FAMILY_INVITE_USED_UP` | 409 | 邀请码已用尽 | 让管理员重发 |
| `FAMILY_MEMBER_LIMIT` | 409 | 家庭人数达上限 | - |
| `FAMILY_NOT_ADMIN` | 403 | 不是管理员 | - |
| `UPLOAD_OBJECT_EXPIRED` | 410 | 直传凭据过期 | 重新申请 |
| `AI_INSUFFICIENT_CREDIT` | 422 | 积分不足 | 引导充值 |
| `AI_PLAY_NOT_AVAILABLE` | 422 | 玩法不可用 | - |
| `AI_INPUT_NOT_FOUND` | 404 | AI 输入对象失效 | 重新上传 |
| `AI_RATE_LIMITED` | 429 | 提交过频 | 退避 |
| `AI_AUDIT_REJECTED` | 422 | 审核拒绝 | 显示申诉入口 |
| `POST_ITEM_LIMIT` | 422 | 媒体数超限 | - |
| `POST_AUDIT_REJECTED` | 422 | UGC 拒绝 | 修改后重试 |
| `CREDIT_SIGN_IN_DONE` | 409 | 今日已签到 | - |
| `IAP_VERIFY_FAILED` | 422 | IAP 校验失败 | 提示重试 / 联系客服 |
| `IAP_USER_MISMATCH` | 409 | 凭据绑定其他账号 | 提示客服 |
| `SUB_PRODUCT_NOT_FOUND` | 404 | SKU 不存在 | - |
| `BACKUP_AUTH_REVOKED` | 401 | 第三方授权失效 | 引导重新授权 |
| `NOTIF_TOKEN_INVALID` | 422 | APNs Token 无效 | 重新注册 |
| `CAPTION_DAILY_LIMIT` | 429 | 今日额度用尽 | - |
| `SYS_INTERNAL` | 500 | 内部错误 | 退避重试 |
| `SYS_UPSTREAM_UNAVAILABLE` | 503 | 上游不可用 | 退避重试 |

---

## 13. 版本化

- 大版本：URI `v1`，破坏性变更升至 `v2`，老版本至少维护 6 个月。
- 非破坏性变更：保留旧字段 + 增加新字段，端侧需对未知字段宽容（前向兼容）。
- 灰度发布：通过 `X-App-Version` + 用户 region 进行路由；新接口可先以 `X-Feature: alpha` 启用。

---

## 14. 调用矩阵（端 ↔ 服务）速查

| 业务流 | 调用 | 服务 |
| --- | --- | --- |
| 登录 / 注销 | `/v1/auth/*`、`/v1/account/*` | auth-family-svc |
| 家庭管理 | `/v1/families/*`、`/v1/invitations/*`、`/v1/babies/*` | auth-family-svc |
| 拍照 / 编辑 | 本地，不调后端 | - |
| AI 任务 | `/v1/uploads/init`、`/v1/ai/*`、WS `/v1/ws/ai` | media-svc + ai-dispatch-svc |
| 发布 / 家庭圈 | `/v1/uploads/init`、`/v1/posts*`、`/v1/feeds/family` | media-svc + feed-svc |
| 智能文案 | `/v1/caption/generate` | caption-svc |
| 积分 / 订阅 / 广告 | `/v1/credits/*`、`/v1/subscriptions/*` | credit-sub-ad-svc |
| 通知 | `/v1/notifications/*` | notification-svc |
| 备份凭据 | `/v1/backup/*` | auth-family-svc |

---

> 端侧实现见 [design-ios.md](./design-ios.md)；后端实现见 [design-backend.md](./design-backend.md)。
