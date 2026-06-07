# P5 家庭圈/分享/文案/通知 端到端回归（T5.20）

> 流程：**智能文案 → 发布 → 家人推送 → Feed 浏览 → 点赞评论 → 撤回；微信/系统分享；UGC 拒绝 + 申诉**  
> 服务：`feed-svc` · `caption-svc` · `notification-svc` · 契约：[contracts/openapi/paths/posts.yaml](../../contracts/openapi/paths/posts.yaml) · [caption.yaml](../../contracts/openapi/paths/caption.yaml) · [notifications.yaml](../../contracts/openapi/paths/notifications.yaml)

## 目录

```text
tests/e2e/
├── README-p5-feed.md                              # 本文件
├── p5-e2e.sh                                      # API E2E shell（mock / staging）
├── p5-feed.env.example                            # P5 环境变量模板
tests/mocks/api/
└── mock_server.py                                 # Python fallback（含 P5 状态机）
```

## 快速开始（Mock 模式）

```bash
# 1. 启动 Mock API
cd tests/mocks/api && python3 mock_server.py

# 2. 跑 P5 E2E
cd ../../e2e && chmod +x p5-e2e.sh && ./p5-e2e.sh
```

预期末尾：

`P5 Feed E2E PASSED: caption · ugc reject+appeal · publish/push/feed/engage/withdraw · wechat · system share · notifications`

## 场景与 Mock 触发

| 场景 | 触发方式 | 预期 |
| --- | --- | --- |
| A 智能文案 | `POST /v1/caption/generate` ×2 + Header `caption_limit` | 3 候选 · 缓存命中 · 429 `CAPTION_DAILY_LIMIT` |
| B UGC 拒绝 | caption/comment 含 `reject_spam` | 422 `POST_AUDIT_REJECTED` |
| B 申诉 | `POST /v1/e2e/feed/ugc-appeal` | `appealId` · status=pending |
| C 发布闭环 | admin 发布 → member 通知/Feed/点赞/评论 → admin 撤回 | `FAMILY_ACTIVITY` 推送 · Feed 不含已撤回 |
| D 微信分享 | `POST /v1/e2e/share/wechat` scene=timeline/session | 缩略图适配 · 深度合成水印 |
| D 微信未安装 | Header `X-E2E-Scenario: wechat_not_installed` | 422 `SHARE_WECHAT_NOT_INSTALLED` |
| E 系统分享 | `POST /v1/e2e/share/system` | clipboardText · usesSystemShareSheet |
| F 通知类目 | GET/PATCH `/v1/notifications/subscriptions` | 类目开关 |

Mock-only 端点（Python fallback）：

- `POST /v1/e2e/share/wechat` — 模拟 WechatShareAdapter 校验
- `POST /v1/e2e/share/system` — 模拟 SystemShareAdapter + 剪贴板
- `POST /v1/e2e/feed/ugc-appeal` — UGC 误判申诉 stub

## 步骤与 OpenAPI operationId

| # | 步骤 | Method | Path | operationId |
| --- | --- | --- | --- | --- |
| 0 | 健康检查 | GET | `/health` | — |
| 1 | 登录 | POST | `/v1/auth/phone/login` | authPhoneLogin |
| 2 | 智能文案 | POST | `/v1/caption/generate` | captionGenerate |
| 3 | 发布 | POST | `/v1/posts` | postCreate |
| 4 | 注册设备 | POST | `/v1/notifications/devices` | notificationsRegisterDevice |
| 5 | 消息中心 | GET | `/v1/notifications` | notificationsList |
| 6 | Feed | GET | `/v1/feeds/family` | feedListFamily |
| 7 | 点赞 | POST | `/v1/posts/{postId}/likes` | postLike |
| 8 | 评论 | POST | `/v1/posts/{postId}/comments` | postCreateComment |
| 9 | 撤回 | DELETE | `/v1/posts/{postId}` | postDelete |

## 关联 Mock

Python fallback：`tests/mocks/api/mock_server.py`（`POSTS` / `NOTIFICATIONS` / `CAPTION_USERS` 状态机 · 发布限流 · UGC 审核 stub）。

## 验收对照（T5.20）

| 验收项 | 实现 |
| --- | --- |
| 发布 → 推送 → 浏览 → 点赞评论 → 撤回 | Scenario C |
| 微信朋友圈 / 好友 | Scenario D · `/v1/e2e/share/wechat` |
| 系统分享 + 智能文案 | Scenario A + E |
| UGC 拒绝 + 申诉 | Scenario B |
| 全流程 + 异常路径 | wechat_not_installed · caption_limit · ugc reject |

## 相关任务

- T5.1–T5.9：feed / caption / notification 后端
- T5.10–T5.18：iOS FamilyFeed / Share / Caption / Notification
- T5.19：端 ↔ feed-svc 联调
- T5.20：本目录
