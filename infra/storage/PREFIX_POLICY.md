# 对象存储目录前缀策略

> T3.2 产出 — 与 [design-backend.md §4.4](../../docs/design-backend.md) 及 `media-svc` 实现对齐  
> 生命周期配置：[oss-cn/lifecycle-rules.xml](./oss-cn/lifecycle-rules.xml)、[s3-os/lifecycle-rules.json](./s3-os/lifecycle-rules.json)

## 1. 桶与区域

| 区域 | 桶名（占位） | 后端 | CDN |
| --- | --- | --- | --- |
| CN | `baby-camera-cn` | 阿里云 OSS | `cdn-cn.babygrowth.app` |
| OS | `baby-camera-os` | AWS S3 (ap-southeast-1) | `cdn-os.babygrowth.app` |

**隔离原则**：CN 用户数据仅存 CN 桶；OS 用户数据仅存 OS 桶。禁止跨区复制用户 UGC。

## 2. 前缀一览

| 前缀 | 业务 TTL | 生命周期 Expiration | 存储分层 | 写入主体 | 读取 / CDN |
| --- | --- | --- | --- | --- | --- |
| `ai-tmp/` | 24h | **1 天**（OSS/S3 最小粒度） | 标准 | 客户端 STS（`purpose=ai-input`） | 不经 CDN；仅 `ai-dispatch-svc` / 审核读 |
| `ai-out/` | 30d | **30 天** | 标准 | **仅** `ai-dispatch-svc` 服务账号 | CDN 可读；未被发布引用则过期删除 |
| `family/` | 长期 | **无** Expiration | 90d→IA，365d→Archive/Glacier IR | 客户端 STS（`purpose=post-item`）+ `feed-svc` 发布搬运 | CDN 缓存；撤回由 `feed-svc` 异步删 |
| `avatar/` | 长期 | 无 | 180d→IA | `media-svc` / 用户头像上传 | CDN |
| `caption-cache/` | 7d | **7 天** | 标准 | `caption-svc` | 不经 CDN |

## 3. 键名规范

### 3.1 `ai-tmp/` — AI 输入临时区

```
ai-tmp/<userId>/<uploadId>/<clientRef>.<ext>
```

| 段 | 说明 | 示例 |
| --- | --- | --- |
| `userId` | 用户 ID，经 `sanitizeObjectPart` | `usr_01HZ...` |
| `uploadId` | `media-svc` 会话 ID | `upl_a1b2c3d4e5f6` |
| `clientRef` | 端侧客户端引用 | `c1` |
| `ext` | 由 MIME 推导 | `.heic`、`.jpg`、`.mp4` |

- **STS 范围**：`ai-tmp/<userId>/*`（init 时按 userId 限定）
- **禁止**：客户端写 `ai-out/`、`family/` 最终发布路径

### 3.2 `ai-out/` — AI 输出区

```
ai-out/<userId>/<taskId>.<ext>
ai-out/<userId>/<taskId>-thumb.jpg
```

- 由 `ai-dispatch-svc` 写入；任务成功后端侧经 CDN 下载至本地 `derived/`
- 用户发布作品时，`feed-svc` 将引用迁移/复制至 `family/`（T5.x）
- 30 天内未被 `family/` 引用的对象由生命周期自动清理

### 3.3 `family/` — 家庭圈发布区（长期）

```
family/<familyId>/post/<postId>/<itemId>.<ext>
family/<familyId>/post/<postId>/thumb/<itemId>_512.jpg
family/<familyId>/pending/<uploadId>/<clientRef>.<ext>   # 直传待发布（STS post-item）
```

| 路径 | 说明 |
| --- | --- |
| `.../pending/...` | `media-svc` init 直传 staging；发布成功后 `feed-svc` 搬运至 `post/` |
| `.../post/...` | 已发布作品；**无自动 Expiration** |
| `.../thumb/...` | 缩略图；CDN TTL 24h |

- **撤回发布**（T5.5）：`feed-svc` 标记软删 → 异步删除 OSS 对象 → 删除事件对账（本目录 [scripts/reconcile-deletes.sh](./scripts/reconcile-deletes.sh)）
- **分层**：仅降冷，不自动删；合规物理删走业务任务

### 3.4 其他前缀

```
avatar/<userId>.jpg
avatar/<babyId>.jpg
caption-cache/<sha256>.json
```

## 4. STS purpose 与前缀映射

| `purpose`（media-svc） | 允许前缀 | 生命周期 |
| --- | --- | --- |
| `ai-input` | `ai-tmp/<userId>/*` | 24h（规则 1 天） |
| `post-item` | `family/<familyId>/pending/<uploadId>/*` | 长期（pending 由 feed 搬运或清理） |

后端服务账号（非 STS）额外权限见 [bucket-policy 模板](./oss-cn/bucket-policy.json.template)。

## 5. 删除与对账

| 触发源 | 事件 | 对账方 |
| --- | --- | --- |
| 生命周期到期 | `LifecycleExpiration` / S3 lifecycle | `media-svc` 标记 upload 会话过期；`ai-dispatch` 清理任务引用 |
| 用户撤回 | `ObjectRemoved:DeleteObject` | `feed-svc` ↔ `media-svc` 对账 post 附件 |
| 合规 / 注销 | 批量 Delete | `auth-family-svc` 审计 + 对账 Cron |

事件通知模板：

- CN：[oss-cn/event-notification.yaml](./oss-cn/event-notification.yaml)
- OS：[s3-os/event-notification.json.template](./s3-os/event-notification.json.template)

对账 Cron：[helm/baobao-storage-lifecycle](./helm/baobao-storage-lifecycle/) 或 [scripts/reconcile-deletes.sh](./scripts/reconcile-deletes.sh)。

## 6. 验收对照（T3.2）

| 检查项 | 期望 | 验证方式 |
| --- | --- | --- |
| `ai-tmp/` 规则 | Expiration = 1 天 | `./scripts/verify-lifecycle.sh` |
| `ai-out/` 规则 | Expiration = 30 天 | 同上 |
| `family/` 规则 | 无 Expiration；有 IA/Archive 过渡 | 同上 |
| 删除事件 | 已配置 MNS/SQS 订阅 | 检查 event-notification 模板 |
| 对账日志 | Cron 输出 `RECONCILE:` 行 | 部署 reconciler CronJob 后查 Pod 日志 |
