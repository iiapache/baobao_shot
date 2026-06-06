# App Store 与 App 内 ICP 备案号占位

> **任务**：T0.10 预填占位 → T7.2 正式回填 → T7.13 提审  
> **原则**：所有 `{{ICP_NUMBER}}` 在管局下发正式号后 **同一批次替换**，并与 [ICP_FILING_TRACKER.md](./ICP_FILING_TRACKER.md) 同步。  
> **关联**：`docs/PRD.md` §4.15 关于页、`docs/dev-plan.md` T6.10 / T7.2 / T7.13

---

## 1. App 名称（与备案一致）

| 字段 | 占位 / 锁定值 |
| --- | --- |
| App Store Connect → App 信息 → 名称 | **宝宝成长相机** |
| 副标题（Subtitle，可选） | 成长日历 · AI 共创家庭相机 |
| 备案平台 App 名称 | **宝宝成长相机**（必须与上表「名称」一致） |

---

## 2. App Store Connect 介绍页占位

### 2.1 描述（Description）页脚

```text
…（产品描述正文，T7.13 定稿）…

ICP备案号：{{ICP_NUMBER}}
算法备案信息见 App 内「设置 → 关于」及隐私政策。
```

### 2.2 推广文本 / 关键词（可选）

推广文本中 **不写** 虚假备案号；未获正式号前不写 ICP 行。

### 2.3 App 隐私问卷（App Privacy）

| 问卷项 | 占位说明 |
| --- | --- |
| 数据收集 | 按 PRD §6 与 T7.13 清单填写 |
| 第三方 SDK | 链接 T7.2 第三方 SDK 清单 |
| 中国区合规 | 备注：已完成 App ICP 备案，备案号 {{ICP_NUMBER}}（提审前替换） |

### 2.4 App Store 审核备注（Review Notes）

```text
中国区 ICP App 备案号：{{ICP_NUMBER}}
备案 App 名称与 App Store 名称一致：宝宝成长相机
隐私政策：https://{{POLICY_HOST}}/privacy-cn.html
用户协议：https://{{POLICY_HOST}}/terms-cn.html
深度合成说明：https://{{POLICY_HOST}}/deep-synthesis-cn.html
算法备案号：见 App 内「设置 → 关于」（T7.1 配置）
```

---

## 3. App 内「设置 → 关于」占位（T6.10）

> 设计参考：`docs/PRD.md` §4.15 · `docs/dev-plan.md` T6.10 — 备案号 **拉远端配置**，不写死。

### 3.1 远端配置 Schema（config-svc）

| Key | 类型 | 占位值 | 说明 |
| --- | --- | --- | --- |
| `compliance.icp_number` | string | `{{ICP_NUMBER}}` | 关于页展示；空则隐藏或显示「备案办理中」 |
| `compliance.icp_query_url` | string | `https://beian.miit.gov.cn/` | 点击备案号跳转（可选） |
| `compliance.algorithm_filing_summary` | string | `{{ALGO_FILING_PLACEHOLDER}}` | T7.1 算法备案，与 ICP 独立 |
| `compliance.policy_urls.privacy_cn` | string | `https://{{POLICY_HOST}}/privacy-cn.html` | T7.2 |
| `compliance.policy_urls.terms_cn` | string | `https://{{POLICY_HOST}}/terms-cn.html` | T7.2 |
| `compliance.policy_urls.deep_synthesis_cn` | string | `https://{{POLICY_HOST}}/deep-synthesis-cn.html` | T7.2 |

### 3.2 关于页 UI 文案占位（i18n key 建议）

| Key | 中文占位文案 |
| --- | --- |
| `settings.about.icp_label` | ICP备案号 |
| `settings.about.icp_value` | `{{ICP_NUMBER}}`（运行时来自 config） |
| `settings.about.icp_pending` | 备案办理中 |
| `settings.about.algorithm_label` | 算法备案号 |
| `settings.about.version_label` | 版本 |

**关于页结构（节选）**：

```text
设置 → 关于
├── 版本          1.0.0 (build)
├── 用户协议      → 网页
├── 隐私政策      → 网页
├── 深度合成说明  → 网页
├── ICP备案号     {{ICP_NUMBER}}     ← config-svc
└── 算法备案号    {{ALGO_FILING}}    ← config-svc（T7.1）
```

### 3.3 未获正式备案号前的展示策略

| 环境 | 关于页 ICP 行 |
| --- | --- |
| dev / staging | 显示 `settings.about.icp_pending` 或占位 `{{ICP_NUMBER}}` |
| TestFlight（CN） | 若管局已受理但未下号：可显示「备案办理中」+ 受理回执编号（产品决策） |
| App Store 生产 | **必须** 显示正式 `{{ICP_NUMBER}}`，否则不得提审中国区 |

---

## 4. 隐私政策 / 用户协议网页占位（T7.2 法务终稿）

页脚模板：

```html
<!-- privacy-cn.html / terms-cn.html 页脚 -->
<p>运营者：{{COMPANY_NAME}}</p>
<p>App ICP备案号：{{ICP_NUMBER}}</p>
<p>联系方式：{{SUPPORT_EMAIL}}</p>
```

---

## 5. T7.13 提审材料交叉引用

| 材料 | ICP 相关字段 | 占位状态 |
| --- | --- | --- |
| App Store 描述页脚 | `{{ICP_NUMBER}}` | 已占位 |
| 审核备注 | 备案号 + 政策 URL | 已占位 |
| App 内关于页 | `compliance.icp_number` | 已占位 |
| 隐私政策网页 | 页脚 ICP | 已占位 |
| 算法备案号 | T7.1 独立字段 | 见 T0.9 算法备案目录 |

**提审前自检**（T7.13）：

- [ ] `{{ICP_NUMBER}}` 已在本文档、Tracker、config-svc、关于页、政策页 **五处一致**
- [ ] App 名称「宝宝成长相机」与备案系统一致
- [ ] 工信部备案系统可查询到该 App 备案记录

---

## 6. 占位符索引

| 占位符 | 含义 | 回填任务 |
| --- | --- | --- |
| `{{ICP_NUMBER}}` | App ICP 备案号 | T7.2 |
| `{{WEB_ICP_NUMBER}}` | 网站 ICP 号（如有独立域名） | T7.2 |
| `{{COMPANY_NAME}}` | 运营主体 | SUBJECT_VERIFICATION |
| `{{POLICY_HOST}}` | 政策页域名 | T7.2 INFRA |
| `{{ALGO_FILING_PLACEHOLDER}}` | 算法备案摘要 | T7.1 |
| `{{SUPPORT_EMAIL}}` | 客服邮箱 | T6.13 |

---

## 7. 更新记录

| 日期 | 变更 |
| --- | --- |
| 2026-06-06 | T0.10 初版：App Store + 设置页 + 政策页占位 |
