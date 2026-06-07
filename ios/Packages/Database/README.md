# Database

GRDB SQLite 层：Schema Migration、Repository、同步占位（T0.16 / T2.4）。

## Migration

| 版本 | 内容 |
| --- | --- |
| `v1_initial` | 11 张核心表：`baby` / `photo` / `derived` / `ai_task_local` / `post_cache` / `comment_cache` / `like_cache` / `membership` / `credit_txn_cache` / `milestone` / `setting` |
| `v1_1_family_sync` | `family` 表 + `membership.updatedAt` |

历史 migration **禁止编辑**，仅追加新版本（见 `DatabaseMigrator.swift` 注释）。

## 用法

```swift
// 冷启动：建库 + 迁移
let db = try AppDatabase.make(at: path)

// 测试 / Preview
let memory = try AppDatabase.makeInMemory()
```

## 验收（T2.4）

- `MigrationTests`：表/列/索引、`v1_initial` 11 表、迁移幂等回放、冷启动 ≤ 200ms
- 冷启动预算：`testColdStartMigrationCompletesWithinBudget`（真机/模拟器；CI 防回归）

## 测试

```bash
cd ios/Packages/Database
swift test   # 需 Xcode + iOS Simulator SDK
```
