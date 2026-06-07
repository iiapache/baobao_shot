# App Store 与 App 内合规元数据（T7.2 结构回填）

> **任务**：T0.10 预填占位 → **T7.2 政策结构回填** → **T7.13 提审材料**  
> **原则**：政策 URL / 版本号与 `compliance/policies/` frontmatter、`config-svc` variant **同一批次**更新。  
> **关联**：`docs/PRD.md` §4.15、`docs/dev-plan.md` T6.10 / T7.2 / T7.13、`compliance/policies/README.md`  
> **T7.13 提审材料**（本文件元数据的上架执行层）：
> - [SUBMISSION_CHECKLIST.md](../app-store/SUBMISSION_CHECKLIST.md) — 提审自查（含 4.5.4 / 4.7 / ATT / 隐私问卷）
> - [APP_REVIEW_NOTES.md](../app-store/APP_REVIEW_NOTES.md) — App Store Connect 审核备注
> - [IAP_PRODUCTS.md](../app-store/IAP_PRODUCTS.md) — 内购 Product ID 与价格占位
> - [SUBSCRIPTION_DISCLOSURE.md](../app-store/SUBSCRIPTION_DISCLOSURE.md) — 订阅披露文案（4.5.4）

---

## 1. App 名称（与备案一致）

| 字段 | 值 |
| --- | --- |
| App Store Connect → 名称 | **宝宝成长相机** |
| 副标题（可选） | 成长日历 · AI 共创家庭相机 |
| 备案平台 App 名称 | **宝宝成长相机**（须与上表一致） |

---

## 2. 政策网页（staging 占位，T7.2）

| 文档 | 源文件 | 托管 URL | 当前版本 | 生效日 |
| --- | --- | --- | --- | --- |
| 隐私政策（CN） | `compliance/policies/privacy-policy-cn.md` | https://www.babycamera.app/legal/privacy-policy-cn | v1.0.0 | 2026-06-06 |
| 隐私政策（OS） | `compliance/policies/privacy-policy-os.md` | https://www.babycamera.app/legal/privacy-policy-os | v1.0.0 | 2026-06-06 |
| 用户协议 | `compliance/policies/terms-of-service.md` | https://www.babycamera.app/legal/terms-of-service | v1.0.0 | 2026-06-06 |
| 深度合成说明 | `compliance/policies/deep-synthesis-notice.md` | https://www.babycamera.app/legal/deep-synthesis-notice | v1.0.0 | 2026-06-06 |
| 第三方 SDK 清单 | `compliance/policies/third-party-sdk-list.md` | https://www.babycamera.app/legal/third-party-sdk-list | v1.0.0 | 2026-06-06 |

> `{{POLICY_HOST}}` 正式值：**www.babycamera.app**（staging 与生产同路径，由 INFRA 部署静态页）

---

## 3. App Store Connect 介绍页

### 3.1 描述（Description）页脚

```text
…（产品描述正文，T7.13 定稿）…

隐私政策：https://www.babycamera.app/legal/privacy-policy-cn（v1.0.0）
用户协议：https://www.babycamera.app/legal/terms-of-service（v1.0.0）
第三方 SDK 清单：https://www.babycamera.app/legal/third-party-sdk-list（v1.0.0）

ICP备案号：{{ICP_NUMBER}}
算法备案信息见 App 内「设置 → 关于」及深度合成说明。
```

### 3.2 App 隐私问卷（App Privacy）

| 问卷项 | 说明 |
| --- | --- |
| 数据收集 | 按 PRD §6 与 T7.13 清单填写 |
| 第三方 SDK | 引用 https://www.babycamera.app/legal/third-party-sdk-list |
| 中国区合规 | 已完成 App ICP 备案，备案号 {{ICP_NUMBER}}（提审前替换） |

### 3.3 App Store 审核备注（Review Notes）

> **T7.13 定稿**：完整审核备注（含 ATT 不申请、远端配置 4.7 说明、演示账号、订阅披露）见  
> **[APP_REVIEW_NOTES.md](../app-store/APP_REVIEW_NOTES.md) §1**，提审时直接粘贴至 ASC。

```text
（摘要 — 完整版见 APP_REVIEW_NOTES.md）

中国区 ICP App 备案号：{{ICP_NUMBER}}
备案 App 名称与 App Store 名称一致：宝宝成长相机

隐私政策（CN）：https://www.babycamera.app/legal/privacy-policy-cn（v1.0.0）
隐私政策（OS）：https://www.babycamera.app/legal/privacy-policy-os（v1.0.0）
用户协议：https://www.babycamera.app/legal/terms-of-service（v1.0.0）
深度合成说明：https://www.babycamera.app/legal/deep-synthesis-notice（v1.0.0）
第三方 SDK 清单：https://www.babycamera.app/legal/third-party-sdk-list（v1.0.0）

算法备案号：见 App 内「设置 → 关于」（T7.1 config-svc 远端热更新）
ATT：不申请，未配置 NSUserTrackingUsageDescription（见 APP_REVIEW_NOTES.md §ATT）
远端配置：仅 JSON，无可执行代码（4.7，见 APP_REVIEW_NOTES.md §远端配置）
订阅披露：见 SUBSCRIPTION_DISCLOSURE.md；IAP 清单见 IAP_PRODUCTS.md
微信分享：仅朋友圈/好友，无小程序代发（见隐私政策摘要）
```

---

## 4. App 内「设置」入口（T6.10 + T7.2）

### 4.1 关于页

```text
设置 → 关于
├── 版本              1.0.0 (build)
├── 用户协议          v1.0.0 → 网页
├── 隐私政策          v1.0.0 → 网页（CN/OS 按 region）
├── 深度合成说明      v1.0.0 → 网页
├── 第三方 SDK 清单   v1.0.0 → 网页
├── ICP备案号         {{ICP_NUMBER}} / 备案办理中
└── 算法备案号        config-svc（T7.1）
```

### 4.2 隐私页

```text
设置 → 隐私
├── 系统授权（相机/相册/通知/定位）
├── 儿童信息监护人同意
├── 隐私政策          v1.0.0 → 网页
└── 第三方 SDK 清单   v1.0.0 → 网页
```

---

## 5. config-svc 远端配置 Schema

| Key | 类型 | 当前占位值 | 说明 |
| --- | --- | --- | --- |
| `compliance.icp_number` | string | `京ICP备00000000号-9S`（staging） | 关于页 ICP；见 `compliance/client-config.yaml` |
| `compliance.icp_query_url` | string | `https://beian.miit.gov.cn/` | 点击备案号跳转 |
| `compliance.algorithm_filing_summary` | string | 见 `client-config.yaml` | T7.1 / AI Tab 页脚 |
| `compliance.algorithm_filing_bindings` | JSON | 见 `client-config.yaml` | ai-dispatch-svc 模型绑定 |
| `compliance.policy_urls.privacy_cn` | string | `https://www.babycamera.app/legal/privacy-policy-cn` | CN 隐私政策 |
| `compliance.policy_urls.privacy_os` | string | `https://www.babycamera.app/legal/privacy-policy-os` | OS 隐私政策 |
| `compliance.policy_urls.terms_cn` | string | `https://www.babycamera.app/legal/terms-of-service` | 用户协议 |
| `compliance.policy_urls.deep_synthesis_cn` | string | `https://www.babycamera.app/legal/deep-synthesis-notice` | 深度合成说明 |
| `compliance.policy_urls.third_party_sdk` | string | `https://www.babycamera.app/legal/third-party-sdk-list` | SDK 清单 |
| `compliance.policy_versions.privacy_cn` | string | `v1.0.0` | CN 隐私政策版本 |
| `compliance.policy_versions.privacy_os` | string | `v1.0.0` | OS 隐私政策版本 |
| `compliance.policy_versions.terms` | string | `v1.0.0` | 用户协议版本 |
| `compliance.policy_versions.deep_synthesis` | string | `v1.0.0` | 深度合成说明版本 |
| `compliance.policy_versions.third_party_sdk` | string | `v1.0.0` | SDK 清单版本 |
| `compliance.support_email` | string | `support@babycamera.app` | 政策页脚 / 客服 |

---

## 6. 版本号管理（T7.2）

1. 更新 `compliance/policies/*.md` frontmatter `version` + `effective_date`
2. 部署 HTML 至 `www.babycamera.app/legal/...`
3. 同步 `config-svc` `compliance.policy_versions.*`
4. 更新本文档 §2 表格与 App Store 审核备注
5. App 内关于/隐私页副标题自动展示远端版本（fallback `v1.0.0`）

---

## 7. 政策页脚模板

```html
<p>运营者：{{COMPANY_NAME}}</p>
<p>App ICP备案号：{{ICP_NUMBER}}</p>
<p>政策版本：v1.0.0 · 生效日期：2026-06-06</p>
<p>联系方式：support@babycamera.app</p>
```

---

## 8. T7.13 提审自检

> 完整自查清单（含算法备案、深度合成、订阅 4.5.4、隐私问卷、IAP、ATT、远端配置 4.7）见  
> **[SUBMISSION_CHECKLIST.md](../app-store/SUBMISSION_CHECKLIST.md)**。

- [ ] `{{ICP_NUMBER}}` 已在 Tracker、config-svc、关于页、政策页 **一致**
- [ ] 政策 URL 在 App Store 描述 + 审核备注 + App 内可打开
- [ ] 政策版本号在 App 内与网页 frontmatter 一致
- [ ] App 名称「宝宝成长相机」与备案系统一致
- [ ] 第三方 SDK 清单与 App Privacy 问卷一致
- [ ] 审核备注已粘贴 [APP_REVIEW_NOTES.md](../app-store/APP_REVIEW_NOTES.md) §1 定稿
- [ ] ASC IAP 与 [IAP_PRODUCTS.md](../app-store/IAP_PRODUCTS.md) Product ID 一致
- [ ] 订阅页披露符合 [SUBSCRIPTION_DISCLOSURE.md](../app-store/SUBSCRIPTION_DISCLOSURE.md)（4.5.4）
- [ ] SUBMISSION_CHECKLIST §D / §H 4.5.4 / 4.7 专项结论已勾选

---

## 9. 占位符索引

| 占位符 | 含义 | 回填任务 |
| --- | --- | --- |
| `{{ICP_NUMBER}}` | App ICP 备案号 | T7.2 管局下号后 |
| `{{COMPANY_NAME}}` | 运营主体 | SUBJECT_VERIFICATION |
| `{{POLICY_HOST}}` | **已定为** www.babycamera.app | T7.2 INFRA 部署 |
| `{{ALGO_FILING_PLACEHOLDER}}` | 算法备案摘要 | T7.1 |
| `{{SUPPORT_EMAIL}}` | 客服邮箱 | T6.13 |

---

## 10. 更新记录

| 日期 | 变更 |
| --- | --- |
| 2026-06-06 | T0.10 初版：App Store + 设置页占位 |
| 2026-06-06 | **T7.2**：政策 MD 源、config-svc URL/版本、App 内版本展示、App Store 结构回填 |
| 2026-06-06 | **T7.13**：交叉引用 `compliance/app-store/` 提审材料四件套 |
