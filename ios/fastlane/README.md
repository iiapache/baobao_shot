# iOS Fastlane

端侧 CI/CD 骨架，配合 GitLab `test:ios` job 与可选 Xcode Cloud。

## 前置

- Ruby + Bundler（推荐 `Gemfile` 锁定 fastlane 版本，T0.13 添加）
- macOS + Xcode（本地单测 / TestFlight）
- Apple Developer 账号（T0.12）

## Lanes

| Lane | 用途 | 状态 |
| --- | --- | --- |
| `test` | `xcodebuild test` / scan | 占位，T0.13 启用 |
| `beta` | TestFlight 上传 | 占位 |
| `release` | App Store 提审 | 占位 |

## 本地运行

```bash
cd ios
# bundle install   # T0.13 添加 Gemfile 后
bundle exec fastlane test
```

## GitLab CI 集成

| 环境 | Job | 说明 |
| --- | --- | --- |
| MR（Linux） | `test:ios` | 验证 Fastfile 存在、`lane :test` 可 grep |
| macOS runner | `test:ios:xcodebuild`（注释模板） | 执行 `bundle exec fastlane test` |
| Xcode Cloud | workflow 配置 | 替代或补充 GitLab iOS 构建 |

在 `.gitlab-ci.yml` 中，`test:ios` 通过 `changes: ios/**/*` 在 MR 时触发。

## Xcode Cloud（可选）

1. 在 Xcode 中启用 Cloud → 创建 Test workflow
2. 触发分支：`main`、PR
3. 动作：`fastlane test` 或内置 Test action
4. 与 GitLab 并行：后端 MR 走 GitLab CI，iOS MR 可走 Xcode Cloud 或 GitLab macOS runner

## 安全

- 证书 / Provisioning Profile 使用 fastlane match，密码存 GitLab Variable `MATCH_PASSWORD`
- 勿提交 `.p12`、`.mobileprovision`、API Key JSON
