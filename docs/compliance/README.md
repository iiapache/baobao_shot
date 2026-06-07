# 合规政策静态页（COMP-02）

App 设置 → 关于 / 隐私 中的政策链接托管于此目录，生产域名映射为 `https://www.babycamera.app/legal/...`。

## 目录

```text
docs/compliance/
├── README.md           # 本文件
└── legal/              # 脚本生成（勿手改 HTML，改源 MD 后重新生成）
    ├── privacy-policy-cn/index.html
    ├── privacy-policy-os/index.html
    ├── terms-of-service/index.html
    ├── deep-synthesis-notice/index.html
    └── third-party-sdk-list/index.html
```

**源文稿**：`compliance/policies/*.md`（法务占位，提审前终稿）。

## 生成

```bash
chmod +x scripts/generate-compliance-docs.sh
./scripts/generate-compliance-docs.sh
```

仅校验源文件：

```bash
./scripts/generate-compliance-docs.sh --check
```

## 本地预览（Debug Scheme 默认基址）

在项目根目录：

```bash
./scripts/generate-compliance-docs.sh
python3 -m http.server 8765 --directory docs
```

| 页面 | 本地 URL |
| --- | --- |
| 隐私政策（CN） | http://localhost:8765/compliance/legal/privacy-policy-cn/ |
| 用户协议 | http://localhost:8765/compliance/legal/terms-of-service/ |
| 深度合成说明 | http://localhost:8765/compliance/legal/deep-synthesis-notice/ |
| 隐私政策（OS） | http://localhost:8765/compliance/legal/privacy-policy-os/ |
| 第三方 SDK 清单 | http://localhost:8765/compliance/legal/third-party-sdk-list/ |

Debug 构建的 `LegalBaseURL` 指向 `http://localhost:8765/compliance/legal`；预览服务须先启动，否则 App 内 Safari 无法打开。

也可直接 `open docs/compliance/legal/terms-of-service/index.html`（`file://` 仅适合人工核对排版）。

## 正式 / Staging 域名

| 环境 | `LegalBaseURL` | 示例 |
| --- | --- | --- |
| Debug | `http://localhost:8765/compliance/legal` | 见上表 |
| Staging | `https://www.babycamera.app/legal` | 占位，INFRA 部署后生效 |
| Release | `https://www.babycamera.app/legal` | 同上 |

config-svc feature flags（`compliance.policy_urls.*`）与 `ComplianceConfig.policyHost` 默认值与此一致；远端可热更新 URL。

## 部署建议

1. CI 在 policy MD 变更时执行 `./scripts/generate-compliance-docs.sh`。
2. 将 `docs/compliance/legal/` 同步至 `www.babycamera.app/legal/`（OSS / Nginx / GitHub Pages）。
3. 更新 `compliance/policies/*.md` frontmatter `version` 时，同步 config-svc `compliance.policy_versions.*`。

## 相关

- 政策源稿说明：`compliance/policies/README.md`
- App Store 元数据：`compliance/icp-filing/APP_STORE_METADATA_PLACEHOLDER.md`
- iOS 配置：`ios/BabyCamera/Resources/Config/*.xcconfig` → `LegalBaseURL`
