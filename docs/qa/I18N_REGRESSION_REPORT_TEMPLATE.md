# 国际化回归报告（i18n Regression Report）

> 任务 **T7.17** · 对齐 [dev-plan.md §10.1](../dev-plan.md#101-子任务清单)  
> 字符串表：`ios/BabyCamera/Resources/Localizable.xcstrings`（237+ keys · zh-Hans）  
> 查找辅助：`ios/Packages/DesignSystem/Sources/DesignSystem/Localization/L10n.swift`  
> 自动化扫描：`scripts/verify-i18n.sh`

---

## 1. 元信息

| 字段 | 值 |
| --- | --- |
| 报告 ID | `T7.17-YYYY-MM-DD-NN` |
| 执行人 | |
| 日期 | |
| 构建号 / Git SHA | |
| 区域 | `zh-Hans`（CN 首发） |
| 测试模式 | `Debug` / `TestFlight` |

---

## 2. 验收标准（必达）

| 维度 | 标准 | 实测 | 结果 |
| --- | --- | --- | --- |
| i18n key 完整 | Settings / Login / Onboarding 用户可见文案均有语义 key | | ☐ Pass ☐ Fail |
| 占位符化 | 含变量文案使用 `%@` / `%lld` 等占位符，非字符串插值硬编码 | | ☐ Pass ☐ Fail |
| 无硬编码中文 | 上述三模块 Sources 无用户可见硬编码中文 | | ☐ Pass ☐ Fail |
| 自动化扫描 | `verify-i18n.sh` 范围违规 = 0 | | ☐ Pass ☐ Fail |
| 真机抽查 | 登录 → 新手引导 → 设置 主路径文案正确 | | ☐ Pass ☐ Fail |

---

## 3. 自动化扫描（CI / 本地）

```bash
# 生成/同步 xcstrings（修改 TRANSLATIONS 后执行）
python3 scripts/generate-i18n-xcstrings.py

# 范围验收（Settings / Login / Onboarding Sources 必须为 0）
./scripts/verify-i18n.sh

# 全局严格模式（可选，后续阶段启用）
./scripts/verify-i18n.sh --strict
```

| 指标 | 阈值 | 实测 | 结果 |
| --- | --- | --- | --- |
| `Localizable.xcstrings` key 数 | ≥ 200 | | ☐ Pass |
| 范围违规（三模块 Sources） | 0 | | ☐ Pass |
| 全局违规（排除 Tests/Preview/E2E） | 记录基线 | | ☐ 记录 |

扫描报告输出目录：`docs/qa/reports/i18n-regression-*.md`

---

## 4. 模块覆盖清单

### 4.1 Login（BabyCameraAccount）

| 视图 / VM | key 前缀 | 硬编码扫描 | 真机抽查 |
| --- | --- | --- | --- |
| `LoginView` | `login.*` / `app.*` | ☐ 0 | ☐ Pass |
| `LoginViewModel` | `login.error.*` | ☐ 0 | ☐ Pass |
| `AccountSettingsView` | `account.*` | ☐ 0 | ☐ Pass |
| `DeleteAccountView` | `account.delete.*` | ☐ 0 | ☐ Pass |
| `AccountCoordinator` | `login.restoring_session` | ☐ 0 | ☐ Pass |

### 4.2 Onboarding（BabyCameraOnboarding）

| 视图 / VM | key 前缀 | 硬编码扫描 | 真机抽查 |
| --- | --- | --- | --- |
| `OnboardingFlowView` | `onboarding.*` / `common.*` | ☐ 0 | ☐ Pass |
| 各 Step 视图 | `onboarding.profile.*` 等 | ☐ 0 | ☐ Pass |
| `OnboardingViewModel` | `onboarding.validation.*` / `onboarding.error.*` | ☐ 0 | ☐ Pass |
| `ChildDataConsent` | `onboarding.consent.*` | ☐ 0 | ☐ Pass |
| `ConsentRestrictedView` | `onboarding.consent.restricted.*` | ☐ 0 | ☐ Pass |

### 4.3 Settings（BabyCameraSettings）

| 视图 / VM | key 前缀 | 硬编码扫描 | 真机抽查 |
| --- | --- | --- | --- |
| `SettingsRootView` | `settings.root.*` / `settings.section.*` | ☐ 0 | ☐ Pass |
| `PrivacySettingsView` | `settings.privacy.*` | ☐ 0 | ☐ Pass |
| `DataSettingsView` | `settings.data.*` | ☐ 0 | ☐ Pass |
| `AboutSettingsView` | `settings.about.*` | ☐ 0 | ☐ Pass |
| 导出 / 缓存 / 备份 / 反馈 | `settings.export.*` 等 | ☐ 0 | ☐ Pass |

---

## 5. 占位符抽检

| key | 占位符 | 示例入参 | 渲染结果 | 结果 |
| --- | --- | --- | --- | --- |
| `settings.data.uninstall_reminder_footer` | `%lld` | `7` | 每 7 天提醒您… | ☐ Pass |
| `settings.privacy.consent.agreed` | `%@` | `child_consent_v1` | 已同意（child_consent_v1） | ☐ Pass |
| `common.step_progress` | `%lld` / `%@` | `2`, `5`, `创建或加入家庭` | 第 2 / 5 步 · … | ☐ Pass |
| `settings.backup.status.failure_with_code` | `%lld`, `%@` | `3`, `NETWORK` | 最近失败 3 次（NETWORK） | ☐ Pass |

---

## 6. 已知排除项

以下路径 **不计入** T7.17 范围违规（由 `verify-i18n.sh` 自动排除）：

- `**/Tests/**` — 单元测试断言与 fixture 数据
- `#Preview` / PreviewProvider — SwiftUI 预览
- `P2E2E` / `P6E2E` / `UITest` — 联调与 UI 测试壳
- 注释（`//`、`/* */`）

以下模块 **后续迭代**（当前仅记录全局基线）：

- Camera / Feed / Timeline / AI Play 等业务模块
- `TimelineHTMLGenerator` 导出 HTML 模板
- 远端 API 错误 message（服务端返回）

---

## 7. 缺陷记录

| ID | 模块 | 描述 | 严重度 | 状态 |
| --- | --- | --- | --- | --- |
| | | | P0/P1/P2 | Open/Fixed |

---

## 8. 结论

| 项 | 结论 |
| --- | --- |
| T7.17 范围验收 | ☐ **通过** · ☐ **不通过** |
| 阻塞上架 | ☐ 是 · ☐ 否 |
| 备注 | |

**签字：** _______________　**日期：** _______________
