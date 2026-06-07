# 埋点事件清单（Analytics Events Catalog）

> 来源：[design-ios.md §15](../design-ios.md#15-埋点核心事件清单--60-项) · 任务 **T7.9**  
> 代码常量：`ios/Packages/BabyCameraDiagnostics/Sources/BabyCameraDiagnostics/Analytics/AnalyticsEventCatalog.swift`  
> 校验脚本：`scripts/verify-analytics-events.sh`

---

## 1. 公共字段（§15.2）

每条事件携带：

| 字段 | 说明 |
| --- | --- |
| `region` | `CN` / `OS` |
| `userId` | 用户 ID 哈希 |
| `babyId` | 当前宝宝 ID 哈希（可选） |
| `appVersion` | 应用版本 |
| `osVersion` | 系统版本 |
| `deviceModel` | 设备型号 |
| `sessionId` | 会话 ID |

不上传照片 / 文案原文；仅事件类型与必要数值。

---

## 2. 上送策略（§15.2）

- 端侧批量打包，每 **30s** 或 **50 条**触发上送。
- 进入后台时立即上送一次。
- 网关写入 ClickHouse（T7.10 看板消费）。

---

## 3. 核心事件（71 项）

### 3.1 启动 / 生命周期（6）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 1 | `app_launch` | 冷 / 热启动完成 | `coldStart` |
| 2 | `app_active` | 进入前台 | — |
| 3 | `app_background` | 进入后台 | — |
| 4 | `app_first_open` | 首次安装打开 | — |
| 5 | `app_crash` | 崩溃前（SDK 侧） | `crashId` |
| 6 | `app_kill` | 用户强杀 / 系统回收（尽力） | — |

### 3.2 账号（5）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 7 | `login_attempt` | 发起登录 | `method` |
| 8 | `login_success` | 登录成功 | `method`, `isNewUser` |
| 9 | `login_failure` | 登录失败 | `method`, `errorCode` |
| 10 | `account_delete` | 账号注销确认 | — |
| 11 | `consent_child_data` | 儿童数据同意书勾选 / 更新 | `version`, `accepted` |

### 3.3 家庭（6）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 12 | `family_create` | 创建家庭 | `familyId` |
| 13 | `family_invite_generate` | 生成邀请码 / 二维码 | `familyId` |
| 14 | `family_join` | 加入家庭 | `familyId`, `relation` |
| 15 | `family_transfer` | 管理员转让完成 | `familyId`, `newAdminUserId` |
| 16 | `family_takeover_vote` | 接管投票操作 | `familyId`, `vote` |
| 17 | `family_member_remove` | 移除成员 | `familyId`, `targetUserId` |

### 3.4 宝宝（3）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 18 | `baby_create` | 创建宝宝 | `babyId` |
| 19 | `baby_update` | 编辑宝宝资料 | `babyId` |
| 20 | `baby_switch` | 切换当前宝宝 | `babyId` |

### 3.5 相机（7）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 21 | `camera_open` | 打开相机页 | — |
| 22 | `camera_capture` | 单张拍摄 | `mediaType` |
| 23 | `camera_burst` | 连拍 | `count` |
| 24 | `camera_filter_apply` | 应用滤镜 | `filterId` |
| 25 | `camera_live_photo` | Live Photo 开关 | `enabled` |
| 26 | `camera_import` | 相册导入 | `count` |
| 27 | `camera_permission_denied` | 相机权限拒绝 | — |

### 3.6 编辑（6）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 28 | `editor_open` | 打开编辑器 | `source`, `elapsedMs` |
| 29 | `editor_apply_filter` | 应用滤镜 | `filterId` |
| 30 | `editor_apply_sticker` | 应用贴纸 | `stickerId` |
| 31 | `editor_apply_text` | 添加文字 | — |
| 32 | `editor_save_derived` | 保存衍生图 | `assetId` |
| 33 | `editor_reopen` | 重新编辑 | `assetId`, `revision` |

### 3.7 AI（8）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 34 | `ai_play_view` | 浏览玩法详情 | `playId` |
| 35 | `ai_submit` | 提交 AI 任务 | `playId`, `taskId` |
| 36 | `ai_credit_preview` | 积分预览 | `playId`, `credits` |
| 37 | `ai_running` | 任务进行中 | `taskId`, `progress` |
| 38 | `ai_success` | 任务成功 | `taskId`, `durationMs` |
| 39 | `ai_failure` | 任务失败 | `taskId`, `errorCode` |
| 40 | `ai_reject` | 审核拒绝 | `taskId`, `reason` |
| 41 | `ai_refund` | 积分退回 | `taskId`, `credits` |

### 3.8 时间线（4）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 42 | `timeline_view_day` | 日视图 | `date` |
| 43 | `timeline_view_month` | 月视图 | `month` |
| 44 | `timeline_view_year` | 年视图 | `year` |
| 45 | `timeline_view_map` | 地图视图 | — |

### 3.9 里程碑（3）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 46 | `milestone_push_received` | 收到里程碑推送 | `milestoneId` |
| 47 | `milestone_template_open` | 打开里程碑模板 | `milestoneId` |
| 48 | `milestone_custom_create` | 创建自定义里程碑 | `milestoneId` |

### 3.10 家庭圈（6）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 49 | `post_compose_open` | 打开发布器 | — |
| 50 | `post_publish` | 发布动态 | `postId` |
| 51 | `post_like` | 点赞 | `postId` |
| 52 | `post_comment` | 评论 | `postId` |
| 53 | `post_delete` | 删除动态 | `postId` |
| 54 | `feed_open` | 打开家庭圈 Feed | `familyId` |

### 3.11 分享（4）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 55 | `share_open` | 打开分享面板 | `assetId` |
| 56 | `share_caption_generate` | AI 生成文案 | `assetId` |
| 57 | `share_to_wechat` | 分享到微信 | `channel` |
| 58 | `share_to_system` | 系统分享 | — |

### 3.12 积分 / 订阅 / 广告（7）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 59 | `credit_balance_view` | 查看积分余额 | `balance` |
| 60 | `credit_signin` | 每日签到 | `streak` |
| 61 | `credit_iap_start` | 发起 IAP | `productId` |
| 62 | `credit_iap_success` | IAP 成功 | `productId`, `credits` |
| 63 | `subscription_purchase` | 订阅购买 | `productId` |
| 64 | `ad_impression` | 广告曝光 | `placement` |
| 65 | `ad_reward_grant` | 激励广告奖励 | `credits` |

### 3.13 备份（4）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 66 | `backup_authorize` | 授权备份目标 | `target` |
| 67 | `backup_run` | 执行备份 | `target`, `bytes` |
| 68 | `backup_failure` | 备份失败 | `target`, `errorCode` |
| 69 | `backup_revoke` | 撤销备份授权 | `target` |

### 3.14 通知（2）

| # | 事件名 | 触发时机 | 关键参数 |
| ---: | --- | --- | --- |
| 70 | `push_token_register` | APNs Token 注册成功 | — |
| 71 | `push_notification_open` | 点击推送进入 App | `type`, `deepLink` |

---

## 4. 扩展事件（实现衍生，2 项）

| # | 事件名 | 分类 | 来源 |
| ---: | --- | --- | --- |
| 72 | `thumbnail_cache_hit` | 性能 / 缓存 | design-ios §15 + T2.21 |
| 73 | `thumbnail_cache_miss` | 性能 / 缓存 | design-ios §15 + T2.21 |

---

## 5. 统计

| 维度 | 数量 |
| --- | ---: |
| §15 核心事件 | 71 |
| 扩展事件 | 2 |
| **合计** | **73** |

---

## 6. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-06-06 | T7.9 初版：自 design-ios §15 提取并补充 ImageKit 缓存事件 |
