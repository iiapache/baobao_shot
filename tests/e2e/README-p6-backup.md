# P6 备份 / Widget / 设置导出 / 注销 端到端回归（T6.15）

> 流程：**三套备份凭据 bind/list/unbind/status（含失败重试）→ Widget 四形态元数据 → 数据导出 zip 可解压 → 登出/注销**  
> 服务：`auth-family-svc` · 契约：[contracts/openapi/paths/backup.yaml](../../contracts/openapi/paths/backup.yaml) · [auth.yaml](../../contracts/openapi/paths/auth.yaml)

## 目录

```text
tests/e2e/
├── README-p6-backup.md          # 本文件
├── p6-e2e.sh                    # API E2E shell（mock / staging）
├── p6-backup.env.example        # P6 环境变量模板（可选）
tests/e2e/ios/
└── P6BackupWidgetSettingsE2ETests.swift   # Widget/设置 smoke（-P6E2E）
tests/mocks/api/
└── mock_server.py               # Python fallback（P6 备份状态机 + export zip）
```

## 快速开始（Mock 模式）

```bash
# 1. 启动 Mock API
cd tests/mocks/api && python3 mock_server.py

# 2. 跑 P6 E2E
cd ../../e2e && chmod +x p6-e2e.sh && ./p6-e2e.sh
```

预期末尾：

`P6 Backup E2E PASSED: icloud/baidu/photos bind · unbind · status retry · widget kinds · export zip · logout/delete`

## 场景与 Mock 触发

| 场景 | 触发方式 | 预期 |
| --- | --- | --- |
| A 三套备份 bind | `POST /v1/backup/providers` kind=icloud/baidu_pan/photos | 200 · active · 无 accessToken 泄露 |
| A upsert | 同 kind 再次 bind | id 不变 · list 仍为 3 条 |
| B 校验 | kind=dropbox / baidu 无 token | 400 `BACKUP_INVALID_PROVIDER` / `COMMON_BAD_PARAM` |
| C unbind | `DELETE /v1/backup/providers/{id}` | 200 · 重复 404 |
| D 失败重试 | `POST /v1/backup/status` success=false ×3 → true | failureCount 1→2→3→0 |
| E Widget | `GET /v1/e2e/backup/widget-kinds` | Small/Medium/Large/LockScreen |
| F 导出 | `POST /v1/account/export` + `GET /v1/e2e/backup/export-sample` | 202 exportId · zip 含 manifest/timeline/photos |
| G 注销 | `POST /v1/account/logout` · `DELETE /v1/account` | 软删 7 天窗口字段 |

Mock-only 端点（Python fallback）：

- `GET /v1/e2e/backup/widget-kinds` — Widget 四形态 smoke 元数据
- `GET /v1/e2e/backup/export-sample` — 最小合法 export zip（Mac `unzip -t` 可验）

## 步骤与 OpenAPI operationId

| # | 步骤 | Method | Path | operationId |
| --- | --- | --- | --- | --- |
| 0 | 健康检查 | GET | `/health` | — |
| 1 | 登录 | POST | `/v1/auth/phone/login` | authPhoneLogin |
| 2 | 绑定备份 | POST | `/v1/backup/providers` | backupBindProvider |
| 3 | 列表 | GET | `/v1/backup/providers` | backupListProviders |
| 4 | 解绑 | DELETE | `/v1/backup/providers/{id}` | backupUnbindProvider |
| 5 | 状态 | GET/POST | `/v1/backup/status` | backupGetStatus / backupReportStatus |
| 6 | 导出请求 | POST | `/v1/account/export` | accountRequestExport |
| 7 | 登出 | POST | `/v1/account/logout` | accountLogout |
| 8 | 注销 | DELETE | `/v1/account` | accountDelete |

## iOS XCUITest smoke（可选）

启动参数：

```text
-UITesting
-P6E2E
```

覆盖：`p6e2eRootView` · Widget 四尺寸标识 · 设置 → 数据 → 导出/备份 · 账号注销入口。

```bash
cd ios && xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' test \
  -only-testing:BabyCameraUITests/P6BackupWidgetSettingsE2ETests
```

## 验收对照（T6.15）

| 验收项 | 实现 |
| --- | --- |
| iCloud / 百度网盘 / 系统相册 三套备份 | Scenario A + C |
| bind/list/unbind/status 全链路 | Scenario A–D |
| 含失败重试 | Scenario D（3 次失败 → 成功清零） |
| Widget 三尺寸 + 锁屏 | Scenario E + iOS smoke |
| 设置导出 | Scenario F · zip 可 Mac 解开 |
| 注销 | Scenario G |

## 相关任务

- T6.6 备份凭据 API · T6.9 Widget · T6.11 数据导出 · T6.15 本 E2E
- iOS 真机 iCloud / 系统相册联调：[ios/docs/ICLOUD_PHOTOS_BACKUP_STAGING.md](../../ios/docs/ICLOUD_PHOTOS_BACKUP_STAGING.md)（OPT-04）
- iOS 真机百度网盘 OAuth：[ios/docs/BAIDU_PAN_OAUTH_STAGING.md](../../ios/docs/BAIDU_PAN_OAUTH_STAGING.md)（OPT-03）
