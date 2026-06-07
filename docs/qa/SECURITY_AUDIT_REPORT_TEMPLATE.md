# 安全审计报告

> 任务 **T7.8** · 对齐 [dev-plan.md §10.1](../dev-plan.md#101-子任务清单) · [design-ios.md §13](../design-ios.md#13-安全)

---

## 1. 元信息

| 字段 | 值 |
| --- | --- |
| 报告 ID | `T7.8-YYYY-MM-DD-NN` |
| 执行人 | |
| 日期 | |
| 构建号 / Git SHA | |
| 渠道 | `Debug` / `TestFlight` / `App Store Connect` |
| 区域 | `CN` / `OS` |
| 自动化检查 | `tests/security/security-checklist.sh` |

---

## 2. 验收清单（必达）

| # | 维度 | 要求 | 自动化 | 实测 | 结果 |
| --- | --- | --- | --- | --- | --- |
| S1 | Keychain Token | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | ☐ | | ☐ Pass ☐ Fail |
| S2 | ATS | `NSAllowsArbitraryLoads = false`，无例外域名放宽 | ☐ | | ☐ Pass ☐ Fail |
| S3 | Cert Pinning | Network 包 stub 存在，生产可配置开启 | ☐ | | ☐ Pass ☐ Fail |
| S4 | 日志脱敏 | Token / 手机号 / Apple Sub 不落明文日志 | ☐ | | ☐ Pass ☐ Fail |
| S5 | App Attest | iOS 14+ stub 存在，IAP / 订阅校验可附 Attestation | ☐ | | ☐ Pass ☐ Fail |
| S6 | 硬编码密钥 | 源码无硬编码 Token / API Key / Secret | ☐ | | ☐ Pass ☐ Fail |
| S7 | 渗透测试 | 逆向不可直接获取 Token（需人工） | — | | ☐ Pass ☐ Fail ☐ N/A |

**自动化入口**：

```bash
chmod +x tests/security/security-checklist.sh
./tests/security/security-checklist.sh
```

---

## 3. Keychain Token 存储

### 3.1 实现位置

| 组件 | 文件 | 服务名 |
| --- | --- | --- |
| 主 Token | `BabyCameraNetwork/TokenStore.swift` → `KeychainTokenStore` | `com.babycamera.app.tokens` |
| 百度网盘 OAuth | `BabyCameraBackup/.../BaiduPanTokenStore.swift` → `KeychainBaiduPanTokenStore` | `com.babycamera.app.baidu-pan` |

### 3.2 属性核查

| 属性 | 期望值 | 实测 |
| --- | --- | --- |
| `kSecClass` | `kSecClassGenericPassword` | |
| `kSecAttrAccessible` | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | |
| 禁止项 | 不得使用 `Always` / `AfterFirstUnlock`（无 ThisDeviceOnly） | |

### 3.3 单测

| 用例 | 结果 | 备注 |
| --- | --- | --- |
| `TokenStoreTests.testKeychainTokenStoreRoundTrip` | ☐ Pass | |
| `TokenStoreTests.testKeychainUsesAfterFirstUnlockThisDeviceOnly` | ☐ Pass | |
| `BaiduPanProviderTests.testKeychainRoundTrip` | ☐ Pass | |

---

## 4. ATS（App Transport Security）

### 4.1 Info.plist 配置

| 键 | 期望值 | 实测 |
| --- | --- | --- |
| `NSAppTransportSecurity` | 存在 | |
| `NSAllowsArbitraryLoads` | `false` | |
| `NSAllowsLocalNetworking` | `false`（生产） | |
| 例外域名 | 无 `NSExceptionAllowsInsecureHTTPLoads` | |

**配置路径**：`ios/BabyCamera/Resources/Info-Supplement.plist`

### 4.2 网络流量抽查

| 端点 | 协议 | 证书有效 | 结果 |
| --- | --- | --- | --- |
| `api-cn.babygrowth.app` | HTTPS | | ☐ |
| `api-os.babygrowth.app` | HTTPS | | ☐ |
| `ws-cn.babygrowth.app` | WSS | | ☐ |

---

## 5. 证书绑定（Cert Pinning）

### 5.1 Stub 配置

| 项 | 值 |
| --- | --- |
| 实现 | `BabyCameraNetwork/Security/CertificatePinning.swift` |
| 开关 | `CertificatePinningConfiguration.isEnabled` |
| 默认（Debug） | `false` |
| 默认（Release 生产） | 按运维下发 SPKI 哈希后开启 |

### 5.2 验证记录

| 场景 | 预期 | 实测 |
| --- | --- | --- |
| 开关关闭 | 正常 TLS 握手 | ☐ |
| 开关开启 + 正确证书 | 请求成功 | ☐ |
| 开关开启 + 错误证书 | 连接拒绝 | ☐ |

---

## 6. 日志脱敏

### 6.1 覆盖矩阵

| 敏感字段 | `LogRedactor`（网络日志） | `FeedbackLogRedactor`（客服反馈） | 占位符 |
| --- | --- | --- | --- |
| Bearer Token | ☐ | ☐ | `[REDACTED]` / `***` |
| `accessToken` JSON | ☐ | ☐ | |
| `refreshToken` JSON | ☐ | ☐ | |
| 手机号（裸号 / `phone` 字段） | ☐ | ☐ | |
| `appleSub` | ☐ | ☐ | |

### 6.2 单测

| 套件 | 用例 | 结果 |
| --- | --- | --- |
| `BabyCameraNetworkTests` | `LoggingRedactionTests` | ☐ Pass |
| `BabyCameraSettingsTests` | `FeedbackLogRedactorTests` | ☐ Pass |

### 6.3 人工抽查

| 步骤 | 结果 |
| --- | --- |
| 登录后触发 API 请求，检查 Console / 诊断日志无明文 Token | ☐ |
| 提交客服反馈，检查邮件附件 JSON 已脱敏 | ☐ |

---

## 7. App Attest

### 7.1 Stub 状态

| 项 | 值 |
| --- | --- |
| 实现 | `BabyCameraAccount/Security/AppAttestService.swift` |
| 最低系统 | iOS 14+（`@available` 守卫） |
| 开关 | `AppAttestConfiguration.isEnabled` |
| 用途 | IAP 收据校验、订阅状态校验时附 Attestation |

### 7.2 验证记录

| 场景 | 预期 | 实测 |
| --- | --- | --- |
| 模拟器 / 开关关闭 | `isSupported == false`，不崩溃 | ☐ |
| 真机 + 开关开启 | `generateKey` / `attestKey` 可调用 | ☐ |
| 后端校验 | Attestation 可被服务端验证（后续 T7.13） | ☐ N/A |

---

## 8. 硬编码密钥扫描

> 由 `security-checklist.sh` 自动执行；人工复核误报。

| 模式 | 命中数 | 备注 |
| --- | --- | --- |
| `Bearer eyJ…` | | |
| `sk_live_` / `sk_test_` | | |
| `"accessToken"\s*:\s*"[a-zA-Z0-9]{20,}"` | | 排除测试 fixture |
| API Key 字面量 | | |

---

## 9. 渗透 / 逆向（人工）

| 项 | 方法 | 结果 | 备注 |
| --- | --- | --- | --- |
| 静态分析 | class-dump / Hopper 搜索 `accessToken` 字符串 | ☐ | |
| 动态调试 | LLDB 断点 `KeychainTokenStore.read` | ☐ | 需越狱或开发证书 |
| 日志泄露 | 抓包 + 本地日志导出 | ☐ | |
| 备份提取 | iTunes 加密备份 Keychain 项 | ☐ | AfterFirstUnlock 应不可跨设备 |

---

## 10. 结论

| 维度 | 结论 |
| --- | --- |
| 自动化静态检查 | ☐ Pass ☐ Fail |
| 单元测试 | ☐ Pass ☐ Fail |
| 人工渗透 | ☐ Pass ☐ Fail ☐ 延期 |
| **总体** | ☐ **可上架** ☐ **需修复后复测** |

### 遗留项 / 风险

| ID | 描述 | 严重度 | 负责人 | 计划修复日 |
| --- | --- | --- | --- | --- |
| | | | | |

### 签核

| 角色 | 姓名 | 日期 | 签字 |
| --- | --- | --- | --- |
| iOS 开发 | | | |
| QA | | | |
| 安全负责人 | | | |
