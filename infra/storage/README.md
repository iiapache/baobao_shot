# 双区对象存储架构

> T0.5 产出 — 阿里云 OSS（CN）+ AWS S3（OS）+ CDN 前置  
> 参考：[design-backend.md §4.4](../../docs/design-backend.md)、[design.md §7.1](../../docs/design.md)

## 1. 设计原则

| 原则 | 说明 |
| --- | --- |
| 区域隔离 | CN 用户数据仅存 `baby-camera-cn`；OS 用户数据仅存 `baby-camera-os`（ap-southeast-1） |
| 原图不上传 | 端侧原图永不经业务服务器；仅 STS 直传临时区 / 发布区 |
| 前缀分域 | `ai-tmp/`、`ai-out/`、`family/` 生命周期与权限独立 |
| CDN 前置 | 已发布作品与 AI 输出经 CDN 分发；`ai-tmp/` 不经 CDN |
| 无仓库凭据 | 桶策略模板使用 `${PLACEHOLDER}`；AK/SK 仅存 Vault |

## 2. 桶与目录结构

```
oss://baby-camera-cn/          s3://baby-camera-os/
├── ai-tmp/<userId>/...        ├── ai-tmp/<userId>/...     # TTL 24h（生命周期 1 天）
├── ai-out/<userId>/...        ├── ai-out/<userId>/...     # TTL 30d
├── family/<familyId>/...      ├── family/<familyId>/...   # 长期保存
├── avatar/<userId>.jpg        ├── avatar/<userId>.jpg
└── caption-cache/<hash>.json  └── caption-cache/<hash>.json
```

### 2.1 生命周期覆盖

| 前缀 | 业务 TTL | OSS（CN） | S3（OS） | 说明 |
| --- | --- | --- | --- | --- |
| `ai-tmp/` | 24h | `lifecycle-rules.xml` → 1 天 Expiration | `lifecycle-rules.json` → 1 天 | OSS/S3 最小过期粒度为 1 天 |
| `ai-out/` | 30d | 30 天 Expiration | 30 天 Expiration | 未被发布引用的输出自动清理 |
| `family/` | 长期 | 无 Expiration；90d→IA，365d→Archive | 无 Expiration；90d→IA，365d→Glacier IR | 撤回发布由 feed-svc 异步删除 |
| `avatar/` | 长期 | 180d→IA | 180d→IA | 头像低频访问 |
| `caption-cache/` | 7d | 7 天 Expiration | 7 天 Expiration | 智能文案缓存 |

配置文件：

- CN：[oss-cn/lifecycle-rules.xml](./oss-cn/lifecycle-rules.xml)
- OS：[s3-os/lifecycle-rules.json](./s3-os/lifecycle-rules.json)

## 3. 桶策略

| 区域 | 模板 | 授权主体 |
| --- | --- | --- |
| CN | [oss-cn/bucket-policy.json.template](./oss-cn/bucket-policy.json.template) | `media-svc` RAM 角色（上传/读）、`feed-svc`（删 family）、CDN 回源角色 |
| OS | [s3-os/bucket-policy.json.template](./s3-os/bucket-policy.json.template) | `media-svc` IAM 角色、CloudFront OAC、`feed-svc` 删除权限 |

部署前替换占位符：

```bash
# 示例（勿提交真实值）
export OSS_BUCKET_NAME=baby-camera-cn
export MEDIA_SVC_RAM_ROLE_ARN=acs:ram::1234567890123456:role/baobao-media-svc-cn
# envsubst < bucket-policy.json.template > bucket-policy.json
```

## 4. CDN

| 区域 | 域名（占位） | 配置 | 回源 |
| --- | --- | --- | --- |
| CN | `cdn-cn.babygrowth.app` | [oss-cn/cdn-origin.yaml](./oss-cn/cdn-origin.yaml) | OSS 私有桶 + RAM 回源鉴权 |
| OS | `cdn-os.babygrowth.app` | [s3-os/cloudfront-distribution.json.template](./s3-os/cloudfront-distribution.json.template) | S3 OAC + CloudFront |

缓存策略：

- 缩略图 `family/*/thumb/*`：TTL 24h
- 发布作品 `family/*`：TTL 1h
- `ai-tmp/`：禁止 CDN 缓存（仅直传，不经 CDN）

## 5. 服务端集成

| 服务 | 存储操作 |
| --- | --- |
| `media-svc` | `POST /v1/uploads/init` 签发 STS；按 `purpose` 路由前缀 |
| `ai-dispatch-svc` | 读 `ai-tmp/`；写 `ai-out/` |
| `feed-svc` | 发布写 `family/`；撤回触发异步删除 + 对账 |
| `caption-svc` | 读写 `caption-cache/` |

STS 策略应限制：

- `ai-input` → `ai-tmp/<userId>/*`
- `post-item` → `family/<familyId>/post/<postId>/*`
- 禁止客户端写 `ai-out/`（仅后端服务账号）

## 6. 验收清单

- [ ] `ai-tmp/` 对象上传后 24h（生命周期 1 天）内自动删除
- [ ] `ai-out/` 对象 30 天后自动删除
- [ ] `family/` 对象无自动 Expiration，撤回后 24h 内物理删除（T5.5）
- [ ] 桶策略拒绝非 HTTPS 与非授权主体写入
- [ ] CDN 仅缓存 `family/`、`ai-out/`、`avatar/` 前缀
- [ ] 凭据来自 Vault，仓库无 AK/SK

## 7. T3.2 — 生命周期部署与删除对账

> 产出：Helm 打包 + 目录策略文档 + 对账 Cron stub + 验收脚本

### 目录

```text
infra/storage/
├── PREFIX_POLICY.md                    # 目录前缀策略（ai-tmp/24h、ai-out/30d、family/长期）
├── scripts/
│   ├── apply-lifecycle.sh              # 应用 OSS/S3 生命周期到云桶
│   ├── verify-lifecycle.sh             # T3.2 验收（本地规则 + 可选远端）
│   └── reconcile-deletes.sh            # 删除事件对账 stub（RECONCILE: 日志）
├── fixtures/delete-events.ndjson       # 对账 stub 样例事件
├── helm/baobao-storage-lifecycle/      # ConfigMap + CronJob
├── oss-cn/event-notification.yaml      # OSS 删除/过期事件 → MNS
└── s3-os/event-notification.json.template
```

### 部署生命周期

```bash
chmod +x infra/storage/scripts/*.sh
./infra/storage/scripts/apply-lifecycle.sh all   # 需 ossutil / aws CLI + Vault 凭据
```

### 部署对账 Cron（K8s）

```bash
helm upgrade --install storage-lifecycle infra/storage/helm/baobao-storage-lifecycle \
  -n baobao-infra --create-namespace \
  -f infra/storage/helm/baobao-storage-lifecycle/values-ack-cn.yaml
# Pod 日志应出现 RECONCILE: status=...
```

### T3.2 验收

```bash
./infra/storage/scripts/verify-lifecycle.sh
# 期望：RESULT: PASS (N/N checks)

RECONCILE_DRY_RUN=1 ./infra/storage/scripts/reconcile-deletes.sh
DELETE_EVENTS_FILE=infra/storage/fixtures/delete-events.ndjson \
  ./infra/storage/scripts/reconcile-deletes.sh
# 期望：RESULT: RECONCILE processed=3 ...
```

| 验收项 | 期望 |
| --- | --- |
| `ai-tmp/` | Expiration 1 天 |
| `ai-out/` | Expiration 30 天 |
| `family/` | 无 Expiration；90d/365d 分层 |
| 删除事件 | event-notification 模板含 ObjectRemoved |
| 对账日志 | `RECONCILE:` 结构化行可见 |

## 8. 相关任务

- T0.5：本目录 + [infra/messaging/kafka/](../messaging/kafka/)
- T3.1：media-svc STS 直传
- T3.2：本节目录策略 + 对账 stub（本节）
- T5.5：撤回发布 OSS 清理 + MNS/SQS 消费者实装
