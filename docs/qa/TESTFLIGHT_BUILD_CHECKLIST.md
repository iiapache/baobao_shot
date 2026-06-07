# TestFlight 构建检查清单（ENV-02）

> **任务 ID**：ENV-02  
> **目标**：Apple Developer 证书 + Provisioning Profile + `fastlane match`，`bundle exec fastlane beta` 产出 IPA 并上传 TestFlight  
> **关联**：[TestFlight 内测计划](./TESTFLIGHT_BETA_PLAN.md) · [第三方账号 §2.1 Apple Developer](../infra/accounts/THIRD_PARTY_ACCOUNTS.md#21-apple-developer) · [ios/fastlane/README.md](../../ios/fastlane/README.md)

---

## 1. 阻塞项总览

| 类别 | 状态 | 说明 |
| --- | --- | --- |
| fastlane 配置（Fastfile / Matchfile / Appfile） | ✅ 仓库已就绪 | 本仓库内可跟随 |
| Gemfile + Bundler | ⚠️ 需本地 `bundle install` | 锁定 fastlane 版本 |
| Apple Developer Program | ❌ **人工** | 需有效会员与 Team ID |
| App Store Connect App 记录 | ❌ **人工** | Bundle ID `com.babycamera.app` |
| match 证书 Git 仓库 | ❌ **人工** | 私有仓库 + `MATCH_PASSWORD` |
| Distribution 证书 + Profile | ❌ **人工** | `match appstore` 生成 |
| App Store Connect API Key | ❌ **人工** | 推荐；或 Apple ID + 应用专用密码 |
| IPA / TestFlight 构建 | ❌ **人工** | 证书就绪后在 macOS 执行 |

**结论**：配置与文档可在无 Apple 账号环境下验收；**IPA 产出必须有人工证书步骤**。

---

## 2. 前置条件

### 2.1 硬件与软件

- [ ] macOS 14+
- [ ] **完整 Xcode 16+**（非仅 Command Line Tools）
- [ ] Ruby 3.x + Bundler（`gem install bundler`）
- [ ] Git SSH 访问 match 证书仓库

验证：

```bash
xcodebuild -version          # 应显示 Xcode 16.x
xcode-select -p              # 应指向 Xcode.app
cd ios && bundle install
```

### 2.2 Apple Developer（人工 — 勿在 CI 日志中打印密钥）

参考 [THIRD_PARTY_ACCOUNTS.md §2.1](../infra/accounts/THIRD_PARTY_ACCOUNTS.md#21-apple-developer)：

- [ ] Apple Developer Program 会员有效
- [ ] 记录 **Team ID**（10 位，如 `AB12CD34EF`）
- [ ] App ID `com.babycamera.app` 已创建，启用：
  - Sign in with Apple
  - Push Notifications
  - In-App Purchase
  - App Groups（`group.app.babycamera`）
  - Associated Domains
- [ ] App ID `com.babycamera.app.widget`（Widget Extension）
- [ ] App Store Connect 已创建 App「宝宝成长相机」

### 2.3 证书 Git 仓库（人工）

- [ ] 在 GitLab / GitHub 创建 **私有空仓库**（例：`babycamera-certificates`）
- [ ] 生成强密码作为 `MATCH_PASSWORD`，存入 GitLab CI Variables（Masked）
- [ ] 运维 / iOS 负责人有仓库读写权限

---

## 3. match 初始化（文档步骤 — 需 Apple 账号，由负责人本地执行一次）

> ⚠️ **以下命令需真实 Apple ID 登录，本仓库自动化不会执行。**  
> 首次生成会写入证书仓库，**勿**将 `.p12`、`.mobileprovision` 提交到应用仓库。

### 3.1 环境变量

在 `ios/` 目录或 shell profile 中 export（示例值请替换）：

```bash
export FASTLANE_TEAM_ID="AB12CD34EF"
export FASTLANE_USER="dev@your-company.com"
export MATCH_GIT_URL="git@gitlab.com:your-org/babycamera-certificates.git"
export MATCH_PASSWORD="your-strong-match-password"
export MATCH_GIT_BRANCH="master"
```

App Store Connect API Key（推荐上传 TestFlight）：

```bash
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/AuthKey_XXXXXXXXXX.p8"
export APP_STORE_CONNECT_API_KEY_ID="XXXXXXXXXX"
export APP_STORE_CONNECT_API_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 3.2 安装依赖

```bash
cd ios
bundle config set --local path 'vendor/bundle'   # 首次：避免系统 Ruby 权限问题
bundle install
```

### 3.3 首次生成 App Store 证书（人工一次）

```bash
cd ios

# 生成 Distribution 证书 + App Store Profile（主 App + Widget）
bundle exec fastlane match appstore --readonly false

# 可选：开发调试证书
bundle exec fastlane match development --readonly false
```

交互提示：

- 首次会要求登录 Apple Developer（`FASTLANE_USER`）
- 若 Keychain 已有冲突证书，按 fastlane 提示处理（通常选创建新证书或 nuke 旧仓库 — **谨慎**）
- 成功后证书仓库出现加密文件，本地 Keychain 安装 Distribution 身份

### 3.4 日常 / CI 只读同步

```bash
cd ios
export MATCH_PASSWORD='***'
bundle exec fastlane sync_signing
# 或
bundle exec fastlane match appstore --readonly
```

---

## 4. 签名状态检测

```bash
cd ios
chmod +x scripts/verify-signing.sh
./scripts/verify-signing.sh
```

| 检查项 | 期望 |
| --- | --- |
| Xcode 16+ | PASS |
| `FASTLANE_TEAM_ID` | 非 `YOUR_TEAM_ID` |
| `MATCH_GIT_URL` | 非占位域名 |
| `MATCH_PASSWORD` | 已设置 |
| Keychain | 含 `Apple Distribution` |
| Provisioning Profiles | ≥ 1 个 |
| match `--readonly` | 成功（可选） |

或通过 fastlane lane：

```bash
cd ios && bundle exec fastlane verify_signing
```

---

## 5. 构建与上传

### 5.1 冒烟门禁（构建前）

```bash
cd tests/mocks && docker compose up -d mock-api
cd ../e2e && ./smoke-critical-path.sh
```

### 5.2 产出 IPA（默认 Staging 配置 → 内测连 Staging API）

```bash
cd ios
export MATCH_PASSWORD='***'
export FASTLANE_TEAM_ID='***'
export MATCH_GIT_URL='git@gitlab.com:org/babycamera-certificates.git'

# 仅 IPA，不上传
bundle exec fastlane build_only
# 产物: ios/build/BabyCamera.ipa
```

### 5.3 构建 + 上传 TestFlight

```bash
cd ios
export MATCH_PASSWORD='***'
export FASTLANE_TEAM_ID='***'
export MATCH_GIT_URL='***'
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/AuthKey_XXX.p8"
export APP_STORE_CONNECT_API_KEY_ID='***'
export APP_STORE_CONNECT_API_ISSUER_ID='***'

bundle exec fastlane beta
```

### 5.4 常用环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `BABYCAMERA_SCHEME` | `BabyCamera-Staging` | Archive Scheme |
| `BABYCAMERA_CONFIGURATION` | `Staging` | Build Configuration |
| `SKIP_UPLOAD` | `false` | `true` 时只构建 IPA |
| `SKIP_MATCH` | `false` | `true` 时跳过 match（已手动装证书） |
| `CI_PIPELINE_IID` | — | 设置时自动递增 `CFBundleVersion` |
| `TESTFLIGHT_CHANGELOG` | 中文默认文案 | TestFlight 更新说明 |

### 5.5 构建后验收

- [ ] `ios/build/BabyCamera.ipa` 存在
- [ ] App Store Connect → TestFlight 出现新 Build
- [ ] Build 处理完成（无「Missing Compliance」等阻塞 — 按 ASC 提示填写）
- [ ] TestFlight 安装后 Scheme 为 Staging，可连 Staging API（见 [ios/README.md](../../ios/README.md) ENV-04）
- [ ] 真机登录测试账号可走通主流程（见 [TESTFLIGHT_USER_GUIDE.md](./TESTFLIGHT_USER_GUIDE.md)）

---

## 6. GitLab CI 变量（macOS runner 启用时）

| 变量 | Masked | 说明 |
| --- | --- | --- |
| `MATCH_PASSWORD` | ✅ | match 加密密码 |
| `MATCH_GIT_URL` | — | 证书仓库 SSH/HTTPS URL |
| `MATCH_GIT_BASIC_AUTHORIZATION` | ✅ | HTTPS 拉仓库时 Base64(user:token) |
| `FASTLANE_TEAM_ID` | — | Apple Team ID |
| `APP_STORE_CONNECT_API_KEY` | ✅ | API Key JSON 或 `.p8` 路径 |
| `APP_STORE_CONNECT_API_KEY_ID` | — | Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | — | Issuer ID |

MR 阶段 Linux `test:ios` 仅验证 Fastfile 存在，**不执行签名**。

---

## 7. ENV-02 完成判定

| 项 | 负责人 | 完成 |
| --- | --- | --- |
| Fastfile / Matchfile / Appfile 就绪 | 研发 | ☑ |
| `verify-signing.sh` 可执行 | 研发 | ☑ |
| 本文档可跟随 | 研发 | ☑ |
| match 证书仓库已初始化 | 运维 / iOS | ☐ |
| `verify-signing.sh` 全 PASS | iOS | ☐ |
| `bundle exec fastlane beta` 产出 IPA | iOS | ☐ |
| TestFlight Build 可安装 | 运营 / QA | ☐ |

**ENV-02 标记 done 条件**：上表后四项全部勾选。

---

## 8. 故障排查

| 现象 | 可能原因 | 处理 |
| --- | --- | --- |
| `No signing certificate "iOS Distribution" found` | 未 match 或 Keychain 无证书 | `bundle exec fastlane match appstore --readonly` |
| `Provisioning profile doesn't match` | Widget Bundle ID 未纳入 match | Matchfile 含 `com.babycamera.app.widget` |
| match clone 失败 | 仓库 URL / SSH / 密码错误 | 检查 `MATCH_GIT_URL`、`MATCH_PASSWORD` |
| `YOUR_TEAM_ID` 报错 | 未 export Team ID | `export FASTLANE_TEAM_ID=...` |
| upload 401 / 403 | API Key 权限不足 | ASC Key 需「Developer」或「App Manager」 |
| Archive 用 Release 连生产 API | Scheme 错误 | 内测用 `BabyCamera-Staging`（默认） |

---

## 9. 变更记录

| 日期 | 说明 |
| --- | --- |
| 2026-06-07 | ENV-02 初版：fastlane match + beta lane + 验证脚本 |
