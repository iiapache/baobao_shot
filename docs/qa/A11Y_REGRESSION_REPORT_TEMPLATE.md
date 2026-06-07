# 可访问性回归报告（Accessibility Regression Report）

> 任务 **T7.16** · 对齐 [dev-plan.md §10.1](../dev-plan.md#101-子任务清单) · [design-ios.md](../design-ios.md)  
> 色板 AA 标注：`ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/DSColors+Accessibility.swift`  
> 自动化 smoke：`tests/e2e/ios/AccessibilitySmokeTests.swift`

---

## 1. 元信息

| 字段 | 值 |
| --- | --- |
| 报告 ID | `T7.16-YYYY-MM-DD-NN` |
| 执行人 | |
| 日期 | |
| 构建号 / Git SHA | |
| 设备 | 例：`iPhone 16 · iOS 18.x` |
| 区域 | `CN` / `OS` |
| 测试模式 | `Debug` / `TestFlight` |

---

## 2. 验收标准（必达）

| 维度 | 标准 | 实测 | 结果 |
| --- | --- | --- | --- |
| Dynamic Type | 关键路径在 **AX5（最大字号）** 下无截断、无重叠 | | ☐ Pass ☐ Fail |
| VoiceOver | 登录 → 设置 → 相机壳 可线性朗读并完成操作 | | ☐ Pass ☐ Fail |
| 对比度 | 正文 ≥ 4.5:1 · 大字号/UI ≥ 3:1（WCAG 2.1 AA） | | ☐ Pass ☐ Fail |
| 深色模式 | Settings 等主要视图使用 `DSColors` 语义色，无硬编码浅色 | | ☐ Pass ☐ Fail |
| 自动化 smoke | `AccessibilitySmokeTests` 全部通过 | | ☐ Pass ☐ Fail |

---

## 3. 自动化 smoke（CI / 本地）

```bash
cd ios
xcodebuild test \
  -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BabyCameraUITests/AccessibilitySmokeTests
```

| 用例 | 覆盖 | 结果 |
| --- | --- | --- |
| `testLoginAccessibilityIdentifiersExist` | 登录页 identifier | ☐ Pass |
| `testSettingsAccessibilityIdentifiersExist` | 设置根视图 identifier | ☐ Pass |
| `testCameraMockAccessibilityIdentifiersExist` | Mock 相机壳 identifier | ☐ Pass |

---

## 4. Dynamic Type 回归

> 路径：**设置 → 辅助功能 → 显示与文字大小 → 更大字体**（或 Xcode Environment Overrides）

| 视图 | AX1 默认 | AX3 偏大 | AX5 最大 | 截断/重叠 | 结果 |
| --- | --- | --- | --- | --- | --- |
| 登录 `LoginView` | | | | | ☐ Pass |
| 设置根 `SettingsRootView` | | | | | ☐ Pass |
| 隐私 `PrivacySettingsView` | | | | | ☐ Pass |
| 数据 `DataSettingsView` | | | | | ☐ Pass |
| 关于 `AboutSettingsView` | | | | | ☐ Pass |
| Mock 相机 `MockCameraView` | | | | | ☐ Pass |

**备注（缺陷编号 / 截图路径）：**

---

## 5. VoiceOver 关键路径

> 开启 VoiceOver（设置 → 辅助功能 → VoiceOver），按序完成下列流程。

### 5.1 登录

| 步骤 | 期望朗读 / 行为 | 实测 | 结果 |
| --- | --- | --- | --- |
| 1 | 聚焦标题区域，听到应用名与副标题 | | ☐ Pass |
| 2 | 「通过 Apple 登录」按钮可读且可激活 | | ☐ Pass |
| 3 | 手机号、验证码字段有 label + hint | | ☐ Pass |
| 4 | 「获取验证码」「手机号登录」可读 | | ☐ Pass |

### 5.2 设置

| 步骤 | 期望朗读 / 行为 | 实测 | 结果 |
| --- | --- | --- | --- |
| 1 | 设置根视图：账号 / 隐私 / 数据 / 通知 / 关于 链接可读 | | ☐ Pass |
| 2 | 各链接 hint 说明跳转目标 | | ☐ Pass |
| 3 | 关于页版本号、法律链接可读 | | ☐ Pass |

### 5.3 相机壳

| 步骤 | 期望朗读 / 行为 | 实测 | 结果 |
| --- | --- | --- | --- |
| 1 | Mock 相机：预览区、拍照、Timeline 按钮可读 | | ☐ Pass |
| 2 | 真机 `CameraViewController`：快门 / 切换镜头 / 闪光灯等工具栏可读 | | ☐ Pass |
| 3 | 顶部宝宝信息浮层合并朗读（姓名 + 天数） | | ☐ Pass |

---

## 6. 对比度抽检（WCAG 2.1 AA）

> 工具：Accessibility Inspector · [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) · `DSColors+Accessibility.verifiedPairs`

| 前景 | 背景 | 模式 | 要求 | 实测比 | 结果 |
| --- | --- | --- | --- | --- | --- |
| `textPrimary` | `background` | Light | ≥ 4.5:1 | ~14.8:1 | ☐ Pass |
| `textPrimary` | `background` | Dark | ≥ 4.5:1 | ~15.2:1 | ☐ Pass |
| `textSecondary` | `background` | Light | ≥ 4.5:1 | ~5.8:1 | ☐ Pass |
| `primary` | `textOnPrimary` | Light | ≥ 4.5:1 | ~5.2:1 | ☐ Pass |
| `error` | `surface` | Light | ≥ 4.5:1 | ~5.1:1 | ☐ Pass |

**新引入色 / 自定义组件补充行：**

| 组件 | 前景 | 背景 | 实测比 | 结果 |
| --- | --- | --- | --- | --- |
| | | | | ☐ Pass |

---

## 7. 深色模式回归

| 视图 | 使用 `DSColors` / 系统语义色 | 硬编码色 | 结果 |
| --- | --- | --- | --- |
| `SettingsRootView` | ☐ | | ☐ Pass |
| `PrivacySettingsView` | ☐ | | ☐ Pass |
| `DataSettingsView` | ☐ | | ☐ Pass |
| `AboutSettingsView` | ☐ | | ☐ Pass |
| `LoginView` | ☐ | | ☐ Pass |

**切换方式：** 设置 → 显示与亮度 → 深色；或 Xcode Environment Overrides → Dark Appearance。

---

## 8. 缺陷汇总

| ID | 严重度 | 视图 | 描述 | 状态 |
| --- | --- | --- | --- | --- |
| A11Y-001 | Blocker / Major / Minor | | | Open / Fixed / Won't fix |

---

## 9. 结论

| 项 | 值 |
| --- | --- |
| 总体结论 | ☐ **通过** · ☐ **有条件通过** · ☐ **不通过** |
| 阻塞项 | |
| 跟进任务 | |
| 签核 | QA · iOS · 产品 |
