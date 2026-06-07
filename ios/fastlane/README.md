# iOS Fastlane

TestFlight / App Store 构建与签名，配合 GitLab CI 与 [TESTFLIGHT_BUILD_CHECKLIST.md](../../docs/qa/TESTFLIGHT_BUILD_CHECKLIST.md)（ENV-02）。

## 前置

| 项 | 要求 |
| --- | --- |
| 系统 | macOS 14+ |
| Xcode | 16+（完整安装） |
| Ruby | 3.x + Bundler |
| Apple | Developer Program + App Store Connect App |
| 证书仓库 | 私有 Git + `MATCH_PASSWORD` |

```bash
cd ios
bundle install
```

## Lanes

| Lane | 用途 |
| --- | --- |
| `test` | SPM + 主工程单测（`scan`） |
| `verify_signing` | 调用 `scripts/verify-signing.sh` |
| `sync_signing` | `match appstore` 同步证书与 Profile |
| `build_ipa` | match + archive，产出 IPA |
| `build_only` | 同 `beta` 但不上传 TestFlight |
| `beta` | 构建 IPA 并 `upload_to_testflight` |
| `release` | App Store 提审（未启用） |

## 快速用法

```bash
cd ios
./scripts/verify-signing.sh          # 检测签名前置
bundle exec fastlane build_only     # 仅 IPA
bundle exec fastlane beta            # IPA + TestFlight
```

默认 **Staging 内测包**：Scheme `BabyCamera-Staging`、Configuration `Staging`（API 见 [ios/README.md](../README.md)）。

## match 初始化（人工一次，需 Apple 账号）

> 本仓库**不包含**真实证书；以下由 iOS / 运维负责人在 macOS 本地执行，**勿**将 `.p12` / `.mobileprovision` 提交到应用仓库。

### 1. 准备

1. Apple Developer Program 有效，记录 **Team ID**
2. App Store Connect 创建 App，Bundle ID `com.babycamera.app`
3. 创建私有 Git 仓库（例 `babycamera-certificates`）
4. 生成 `MATCH_PASSWORD`，写入 GitLab CI Variables（Masked）

### 2. 环境变量

```bash
export FASTLANE_TEAM_ID="AB12CD34EF"
export FASTLANE_USER="dev@your-company.com"
export MATCH_GIT_URL="git@gitlab.com:your-org/babycamera-certificates.git"
export MATCH_PASSWORD="your-strong-password"
```

### 3. 首次生成证书

```bash
cd ios
bundle install

# App Store Distribution（TestFlight 必需）
bundle exec fastlane match appstore --readonly false

# 可选：真机 Debug
bundle exec fastlane match development --readonly false
```

`Matchfile` 已包含：

- `com.babycamera.app`（主 App）
- `com.babycamera.app.widget`（Widget Extension）

### 4. 日常 / CI

```bash
bundle exec fastlane match appstore --readonly
# 或
bundle exec fastlane sync_signing
```

CI 中 `readonly` 默认为 `true`（见 Matchfile `ENV["CI"]`）。

## App Store Connect 上传

推荐 API Key（避免 Apple ID 双因素交互）：

```bash
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/AuthKey_XXXX.p8"
export APP_STORE_CONNECT_API_KEY_ID="XXXX"
export APP_STORE_CONNECT_API_ISSUER_ID="uuid"
bundle exec fastlane beta
```

## GitLab CI

| 环境 | Job | 行为 |
| --- | --- | --- |
| MR（Linux） | `test:ios` | 检查 Fastfile 存在 |
| macOS runner | `test:ios:xcodebuild`（模板） | `bundle exec fastlane test` |
| macOS runner | `build:ios`（待启用） | `bundle exec fastlane beta` |

CI 变量见 [infra/ci/variables.md](../../infra/ci/variables.md)。

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `Appfile` | Bundle ID、Team ID（`FASTLANE_TEAM_ID`） |
| `Matchfile` | match 仓库 URL、App ID 列表 |
| `Fastfile` | lane 定义 |
| `../scripts/verify-signing.sh` | 签名前置检测 |
| `../Gemfile` | fastlane 版本锁定 |

## 安全

- 证书仅存在于 match 加密仓库 + 本地 Keychain
- 勿提交 `.p12`、`.mobileprovision`、API Key `.p8`
- `MATCH_PASSWORD`、API Key 使用 GitLab Masked Variables

## 相关文档

- [TESTFLIGHT_BUILD_CHECKLIST.md](../../docs/qa/TESTFLIGHT_BUILD_CHECKLIST.md) — ENV-02 完整检查清单
- [TESTFLIGHT_BETA_PLAN.md](../../docs/qa/TESTFLIGHT_BETA_PLAN.md) — 内测计划
- [THIRD_PARTY_ACCOUNTS.md §2.1](../../infra/accounts/THIRD_PARTY_ACCOUNTS.md#21-apple-developer) — Apple 账号开通
