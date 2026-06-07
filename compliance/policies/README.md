# 合规政策文档（T7.2）

> **任务**：T7.2 ICP 备案 + 隐私政策 + 用户协议 + 深度合成说明 + 第三方 SDK 清单  
> **托管**：staging 占位 `https://www.babycamera.app/legal/...`（由 INFRA 部署静态页或 MD→HTML 流水线）  
> **关联**：`compliance/icp-filing/APP_STORE_METADATA_PLACEHOLDER.md`、`services/config-svc`

## 文档清单

| 源文件 | 托管路径 | config-svc URL key | 版本 key |
| --- | --- | --- | --- |
| `privacy-policy-cn.md` | `/legal/privacy-policy-cn` | `compliance.policy_urls.privacy_cn` | `compliance.policy_versions.privacy_cn` |
| `privacy-policy-os.md` | `/legal/privacy-policy-os` | `compliance.policy_urls.privacy_os` | `compliance.policy_versions.privacy_os` |
| `terms-of-service.md` | `/legal/terms-of-service` | `compliance.policy_urls.terms_cn` | `compliance.policy_versions.terms` |
| `deep-synthesis-notice.md` | `/legal/deep-synthesis-notice` | `compliance.policy_urls.deep_synthesis_cn` | `compliance.policy_versions.deep_synthesis` |
| `third-party-sdk-list.md` | `/legal/third-party-sdk-list` | `compliance.policy_urls.third_party_sdk` | `compliance.policy_versions.third_party_sdk` |

## 版本号管理

1. **frontmatter**：每份 Markdown 顶部维护 `version`（语义化，如 `v1.0.0`）与 `effective_date`（生效日，如 `2026-06-06`）。
2. **config-svc**：`compliance.policy_versions.*` variant 与 frontmatter `version` **同一批次**更新，便于 App 内展示与远端热更新。
3. **App 内展示**：设置 → 隐私 / 关于 行副标题显示版本号；未拉取到远端时使用 `ComplianceConfig.defaultPolicyVersion`（`v1.0.0`）。
4. **变更流程**：法务定稿 → 更新 MD frontmatter → 部署 HTML → 更新 config-svc variant → App Store 审核备注同步（T7.13）。

## 占位说明

正文为**结构完整之法务占位**，提审前须由法务终稿替换。页脚 ICP 号、运营主体等待 `{{ICP_NUMBER}}` / `{{COMPANY_NAME}}` 正式回填。
