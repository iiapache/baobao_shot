# BabyCameraFamilyFeed — 端 ↔ feed-svc 联调（T5.19）

家庭圈发布、浏览、互动、撤回全链路的 Integration / Coordinator 接线说明。

## 架构

```
App (Scene / Tab)
  └── FeedCoordinator                    ← 全链路编排
        ├── FamilyFeedIntegration        ← 依赖注入工厂
        │     └── FeedIntegrationContext ← REST + 缓存 + WS
        ├── PostComposerViewModel        ← 发布（T5.10）
        └── FeedListViewModel            ← 列表 + 互动（T5.11/T5.12）
              ├── FeedService            → GET /v1/feeds/family
              ├── EngagementService      → POST/DELETE likes & comments
              └── FeedWebSocketClient    → /v1/ws/feed（可选）
```

## 快速接线

```swift
import BabyCameraBaby
import BabyCameraFamilyFeed
import BabyCameraNetwork
import Database

// 1. 冷启动已有 AppDatabase + TokenStore
let appDatabase = try AppDatabase.make(at: dbPath)
let tokenStore = KeychainTokenStore()  // 登录后已有 accessToken

// 2. 装配上下文
let context = FamilyFeedIntegration.makeContext(
    dependencies: .init(
        appDatabase: appDatabase,
        tokenStore: tokenStore,
        familyId: session.familyId,
        currentUserId: session.userId,
        region: .cn,
        webSocket: FeedWebSocketClient()   // 可选，家人实时点赞/评论
    )
)

// 3. Coordinator + ViewModel
let babyEnv = CurrentBabyEnvironment(restorePersistedSelection: true)
let coordinator = FamilyFeedIntegration.makeFeedCoordinator(
    context: context,
    currentBabyEnvironment: babyEnv,
    mentionCandidates: familyMembers.map { FeedMentionCandidate(id: $0.userId, nickname: $0.nickname) }
)
let feedListVM = coordinator.attachFeedList()

// 4. SwiftUI 绑定
FeedListView(viewModel: feedListVM)

// 5. 发布入口（相机 / AI 结果页）
let composer = FamilyFeedIntegration.makePostComposerViewModel(
    context: context,
    baby: currentBaby,
    aiPlayName: playName,
    isSubscribed: subscriptionStore.isActive
)
PostComposerView(viewModel: composer)
```

## 全链路调用顺序

| 步骤 | 调用 | feed-svc API |
| --- | --- | --- |
| 1 发布 | `await coordinator.publish(composer:)` | `POST /v1/posts` |
| 2 刷新 Feed | 发布成功后自动 `feedListVM.reload()` | `GET /v1/feeds/family` |
| 3 点赞 | `await coordinator.like(post:)` | `POST /v1/posts/{id}/likes` |
| 4 评论 | `await coordinator.submitComment(on:text:)` | `POST /v1/posts/{id}/comments` |
| 5 撤回 | `await coordinator.withdraw(postId:)` | `DELETE /v1/posts/{id}` |

发布成功后 `coordinator.lastPublishedPostId` 可用；撤回后 `lastWithdrawnPostId` 更新，列表本地乐观移除并重新拉取。

## WebSocket 订阅

`FeedListViewModel.onAppear` 自动：

1. 用 `accessTokenProvider` 连接 `/v1/ws/feed`
2. `subscribe(familyIds: [familyId])`
3. 收到 `likeAdded` / `commentAdded` 等事件合并到 `engagementByPostId`

离线互动写入 `EngagementOfflineQueue`，联网后 `flushOfflineQueue` 重放。

## 本地缓存

| 表 | 用途 | 上限 |
| --- | --- | --- |
| `post_cache` | Feed 首屏离线 | 每家庭 100 条 |
| `like_cache` / `comment_cache` | 互动离线 | 随 post 关联 |
| `setting` | 离线互动队列 JSON | 按 familyId 隔离 |

撤回时 `PostService.withdraw` 同步删除 `post_cache` 对应行。

## 测试

```bash
cd ios/Packages/BabyCameraFamilyFeed
swift test --filter FeedCoordinatorIntegrationTests
```

`FeedCoordinatorIntegrationTests` 使用 `MockURLProtocol` 模拟 feed-svc 全链路，无需真机或本地 Go 服务。

## 依赖

- `BabyCameraNetwork`：`PostsAPI` / `FeedsAPI` / `EngagementAPI` / `FeedWebSocketClient`
- `Database`：`FeedCacheRepository` / `EngagementOfflineQueue`
- `BabyCameraBaby`：`CurrentBabyEnvironment` / `BabyProfile`
