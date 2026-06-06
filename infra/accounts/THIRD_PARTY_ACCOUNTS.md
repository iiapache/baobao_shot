# 第三方账号开通清单

> **任务**：T0.12  
> **验收**：全部账号可登录（文档 checklist）；测试 Key 可调通；产线 Key 走 Vault  
> **关联**：`docs/design-backend.md` §2–§3、`docs/PRD.md` §4、§6、§7

---

## 1. 总览表

| 账号类型 | 用途 | 负责领域 | 开通状态 | Vault Path（产线） | 测试 Key | 产线 Key |
| --- | --- | --- | :---: | --- | --- | --- |
| Apple Developer | Sign in with Apple、APNs、IAP、App Groups、TestFlight | iOS + auth-family + notification + credit-sub-ad | - [ ] | 见 §2.1 子路径 | Sandbox 内购 + 开发 APNs | Vault `prod-*/{region}/auth-family/apple-sign-in` 等 |
| 微信开放平台 | 微信登录（V1.1）、OpenSDK 分享 | iOS + auth-family | - [ ] | `secret/data/prod-cn/cn/auth-family/wechat-open` | 测试 AppID（开放平台） | Vault 同上 |
| 阿里云短信 | 手机号验证码登录 | auth-family-svc | - [ ] | `secret/data/prod-cn/cn/auth-family/aliyun-sms` | 控制台测试号码 | Vault 同上 |
| 阿里云内容安全 | AI 入参/出参/UGC 审核 | audit-svc | - [ ] | `secret/data/prod-cn/cn/audit/aliyun-green` | 免费试用额度 | Vault 同上 |
| 穿山甲（Pangle） | 国内激励/开屏/插页广告 | iOS SDK + credit-sub-ad 回调验签 | - [ ] | 端：`CI Variables`；服：`.../credit-sub-ad/pangle` | 测试 AppID + 测试广告位 | Vault Server Key |
| 优量汇（GDT） | 国内广告聚合 | iOS SDK + credit-sub-ad | - [ ] | 端：`CI Variables`；服：`.../credit-sub-ad/gdt` | 测试媒体 ID | Vault Server Key |
| AdMob | 海外激励/展示广告 | iOS SDK + credit-sub-ad SSV | - [ ] | 端：`CI Variables`；服：`.../credit-sub-ad/admob` | Google 测试 Ad Unit | Vault + SSV 公钥 URL |
| 字节跳动 / 火山引擎 | Seedream、Jimeng、Seedance | ai-dispatch-svc（CN） | - [ ] | `secret/data/prod-cn/cn/ai-dispatch/bytedance` | 控制台试用 Key | Vault 同上 |
| 阿里云 DashScope | 通义万相、通义千问（caption） | ai-dispatch + caption-svc | - [ ] | `.../ai-dispatch/alibaba-dashscope`、`.../caption/alibaba-qwen` | 免费额度 Key | Vault 同上 |
| OpenAI | GPT Image 2、GPT-4o-mini（caption） | ai-dispatch + caption-svc（OS） | - [ ] | `secret/data/prod-os/os/ai-dispatch/openai`、`.../caption/openai` | Project 测试 Key | Vault；须「不参与训练」端点 |
| Google AI / Vertex | Nano Banana 等 | ai-dispatch-svc（OS） | - [ ] | `secret/data/prod-os/os/ai-dispatch/google` | GCP 试用项目 | Vault 同上 |
| 百度网盘 OpenAPI | 备份 OAuth + 分片上传 | iOS + auth-family 凭据托管 | - [ ] | `secret/data/prod-cn/cn/auth-family/baidu-pan-oauth` | 开发者测试应用 | Vault client secret；用户 token 加密落库 |
| Bugly | iOS 崩溃监控（国内） | iOS | - [ ] | `secret/data/prod-cn/global/platform/bugly`（符号表 CI） | 测试 AppID | CI Protected Variables |
| Sentry | 后端 + iOS 异常追踪 | 全栈 | - [ ] | `secret/data/prod-*/global/platform/sentry` | dev/staging DSN | Vault DSN + auth token |

**图例**：`- [ ]` 未开通 · `- [x]` 已开通 · 开通后由 INFRA 负责人更新本表。

---

## 2. 分账号开通步骤与验证

### 2.1 Apple Developer

| 项 | 说明 |
| --- | --- |
| 控制台 | [developer.apple.com](https://developer.apple.com) |
| 主体 | 公司 Apple Developer Program（年费） |
| 子路径 | `auth-family/apple-sign-in`、`notification/apns`、`credit-sub-ad/apple-iap`、`iap-callback/apple-asn` |

**开通步骤摘要：**

1. 注册/续费 Apple Developer Program，确认 Team ID。
2. 创建 App ID（Bundle ID），启用：Sign in with Apple、Push Notifications、In-App Purchase、App Groups、Associated Domains。
3. 创建 **Sign in with Apple** Service ID + Key（`.p8`）→ 入 Vault `apple-sign-in`。
4. 创建 **APNs Auth Key**（`.p8`）→ 入 Vault `notification/apns`。
5. 创建 **App Store Connect API Key** → 入 Vault `credit-sub-ad/apple-iap`；配置 Server Notifications v2 URL。
6. App Store Connect 创建 App、内购 SKU、沙盒测试账号。
7. Xcode Cloud / fastlane 使用 CI Variables 引用 Team ID、证书（不进 Git）。

**验证方法：**

- [ ] 开发者账号可登录，Membership 有效
- [ ] TestFlight 可上传构建（T0.13 后）
- [ ] 沙盒 IAP 购买成功（T4.4）
- [ ] APNs 测试推送 200（见 `verification-checklist.md` §1）

---

### 2.2 微信开放平台

| 项 | 说明 |
| --- | --- |
| 控制台 | [open.weixin.qq.com](https://open.weixin.qq.com) |
| 用途 | V1.1 微信登录 + OpenSDK 分享（朋友圈/好友） |
| Vault | `secret/data/prod-cn/cn/auth-family/wechat-open` |

**开通步骤摘要：**

1. 注册开放平台开发者账号，完成主体认证。
2. 创建移动应用，填写 iOS Bundle ID、Universal Link。
3. 申请「微信登录」「分享」能力，获取 AppID / AppSecret。
4. AppSecret 写入 Vault；AppID 可出现在端侧 Info.plist（非 Secret）。
5. PRD 约束：不支持公众号/视频号代发，需在隐私政策/SDK 清单披露。

**验证方法：**

- [ ] 开放平台审核通过，应用状态「已上线」或「开发中可调试」
- [ ] 真机调起微信授权（staging）
- [ ] 分享回调 URL 可达

---

### 2.3 阿里云短信

| 项 | 说明 |
| --- | --- |
| 控制台 | 阿里云 → 短信服务 |
| 服务 | auth-family-svc `POST /v1/auth/phone/code` |
| Vault | `secret/data/prod-cn/cn/auth-family/aliyun-sms` |

**开通步骤摘要：**

1. 开通短信服务，申请签名（与应用名一致）与模板（登录验证码）。
2. 创建 RAM 子账号，仅授予 `AliyunDysmsFullAccess`（或更细自定义）。
3. AccessKey 写入 Vault；配置限流 60s/3 次（design-backend §9.1）。
4. 模板变量 `{code}` 与后端生成逻辑对齐。

**验证方法：**

- [ ] 控制台发送测试短信成功
- [ ] staging API 发送验证码，5min TTL 生效
- [ ] 限流触发返回预期错误码

---

### 2.4 阿里云内容安全

| 项 | 说明 |
| --- | --- |
| 控制台 | 阿里云 → 内容安全（Green） |
| 服务 | audit-svc 入参/出参/UGC |
| Vault | `secret/data/prod-cn/cn/audit/aliyun-green` |

**开通步骤摘要：**

1. 开通图像、文本、视频审核场景。
2. RAM 子账号最小权限（仅 Green API）。
3. 配置 bizType / scene，与 audit-svc 管线映射（design-backend §7.2）。
4. 开通按量付费，设置预算告警。

**验证方法：**

- [ ] 控制台在线调试：正常图 pass、违规图 block
- [ ] audit-svc staging 同步审核 ≤3s（入参）
- [ ] 误杀样本可走申诉流程（T7.5）

---

### 2.5 穿山甲（Pangle）

| 项 | 说明 |
| --- | --- |
| 控制台 | [穿山甲媒体平台](https://www.pangolin-dsp.com) |
| 服务 | 端侧聚合 SDK + credit-sub-ad 激励回调验签 |
| Vault | 端 AppID → CI；Server Key → `.../credit-sub-ad/pangle` |

**开通步骤摘要：**

1. 注册媒体账号，创建应用（iOS）。
2. 创建广告位：开屏、插页、激励视频。
3. 获取 AppID、Security Key（服务端验签）。
4. 配置服务端回调 URL → `credit-sub-ad-svc`。
5. 儿童内容：设置类目黑名单（PRD §4.11.5）。

**验证方法：**

- [ ] 测试广告位可展示（测试模式）
- [ ] mock 回调验签通过（见 verification-checklist §5）
- [ ] 单日激励 ≤5 次限制生效

---

### 2.6 优量汇（腾讯广告 GDT）

| 项 | 说明 |
| --- | --- |
| 控制台 | [腾讯广告优量汇](https://e.qq.com/dev) |
| Vault | `.../credit-sub-ad/gdt` |

**开通步骤摘要：**

1. 注册开发者，创建媒体与广告位。
2. 获取 AppID、Secret Key。
3. 配置激励视频 Server 回调与签名校验。
4. 与穿山甲一并接入聚合 SDK（国内）。

**验证方法：**

- [ ] 测试广告加载成功
- [ ] 服务端回调签名验证通过

---

### 2.7 AdMob（Google）

| 项 | 说明 |
| --- | --- |
| 控制台 | [AdMob](https://admob.google.com) |
| 区域 | 海外（prod-os） |
| Vault | `secret/data/prod-os/os/credit-sub-ad/admob` |

**开通步骤摘要：**

1. 关联 Google 账号，创建 iOS 应用与 Ad Unit（激励/插页/开屏）。
2. 启用 Server-side verification（SSV）。
3. App ID / Ad Unit ID → iOS CI Variables；SSV 验签逻辑用 Google 公钥 JSON。
4. 遵守 COPPA / 儿童应用广告政策。

**验证方法：**

- [ ] 测试 Ad Unit 展示 Google 测试广告
- [ ] SSV 回调在 staging 入账积分

---

### 2.8 字节跳动 / 火山引擎（AI）

| 项 | 说明 |
| --- | --- |
| 控制台 | 火山引擎 / 即梦 / Seed 系列开放平台 |
| 模型 | Seedream（生图）、Jimeng（编辑）、Seedance（视频） |
| Vault | `secret/data/prod-cn/cn/ai-dispatch/bytedance` |
| 合规 | 须完成算法备案（T0.9 / T7.1）后产线启用 |

**开通步骤摘要：**

1. 企业认证，开通视觉智能 / 大模型相关产品线。
2. 申请 API Key，确认 QPS 与计费。
3. 签署「不用于训练」/data processing 条款。
4. 备案号写入 `ai-dispatch/model-filing` path。

**验证方法：**

- [ ] 控制台或 curl 调用 Seedream 返回图片 URL
- [ ] Seedance 视频任务异步回调正常
- [ ] ai-dispatch staging Adapter 集成测试通过

---

### 2.9 阿里云 DashScope（通义）

| 项 | 说明 |
| --- | --- |
| 控制台 | [DashScope](https://dashscope.aliyun.com) |
| 模型 | 通义万相（ai-dispatch）、通义千问 Turbo（caption-svc） |
| Vault | `.../ai-dispatch/alibaba-dashscope`、`.../caption/alibaba-qwen` |

**开通步骤摘要：**

1. 开通 DashScope，创建 API-KEY。
2. 开通万相、千问模型权限。
3. 算法备案（T0.9）完成后绑定 filing path。

**验证方法：**

- [ ] API-KEY 调用 wanx 模型成功
- [ ] caption-svc 文案生成 ≤2s（staging）

---

### 2.10 OpenAI

| 项 | 说明 |
| --- | --- |
| 控制台 | [platform.openai.com](https://platform.openai.com) |
| 区域 | 海外 prod-os |
| Vault | `.../ai-dispatch/openai`、`.../caption/openai` |
| 合规 | 标准合同 + 「不参与训练」Organization 设置（T7.4） |

**开通步骤摘要：**

1. 创建 Organization / Project，启用 billing。
2. 创建受限 API Key（仅 images/chat 权限）。
3. 确认 data usage opt-out / Zero Data Retention（如可用）。
4. 海外代理或直连 endpoint 写入 `OPENAI_BASE_URL`。

**验证方法：**

- [ ] images/generations 或 edits API 200
- [ ] 中国区集群 policy 拒绝读取此 path（ai-dispatch-svc.hcl deny）

---

### 2.11 Google AI / Vertex

| 项 | 说明 |
| --- | --- |
| 控制台 | Google Cloud Console / AI Studio |
| 模型 | Nano Banana（Gemini 图像等） |
| Vault | `secret/data/prod-os/os/ai-dispatch/google` |

**开通步骤摘要：**

1. 创建 GCP 项目，启用 Vertex AI / Generative Language API。
2. 创建 API Key 或服务账号（推荐 workload identity）。
3. 配置新加坡区域 endpoint（design-backend §10）。
4. 签署不用于训练条款。

**验证方法：**

- [ ] Vertex predict 或 generateContent 返回有效响应
- [ ] OS ai-dispatch Adapter 单测通过

---

### 2.12 百度网盘 OpenAPI

| 项 | 说明 |
| --- | --- |
| 控制台 | [百度网盘开放平台](https://pan.baidu.com/union) |
| 服务 | 端侧 OAuth + auth-family 凭据托管 |
| Vault | `secret/data/prod-cn/cn/auth-family/baidu-pan-oauth` |

**开通步骤摘要：**

1. 创建应用，申请「网盘」权限 scope。
2. 配置 OAuth redirect URI（与后端 callback 一致）。
3. AppKey / SecretKey 入 Vault；用户 refresh_token 加密存 PostgreSQL。
4. 确认分片上传、quota 查询 API 权限。

**验证方法：**

- [ ] OAuth 授权码流程 staging 闭环
- [ ] 小文件分片上传成功
- [ ] Token 刷新与 revoke 处理正确

---

### 2.13 Bugly

| 项 | 说明 |
| --- | --- |
| 控制台 | [bugly.qq.com](https://bugly.qq.com) |
| 区域 | 国内 iOS 主通道 |
| 存储 | AppID/AppKey → GitLab CI Protected Variables；符号表 token → Vault `platform/bugly` |

**开通步骤摘要：**

1. 注册腾讯 Bugly，创建 iOS 产品。
2. 集成 SDK（design-ios §15 可观测性）。
3. CI 上传 dSYM 使用 Masked token。

**验证方法：**

- [ ] 测试崩溃上报可在控制台看到
- [ ] 符号化堆栈可读

---

### 2.14 Sentry

| 项 | 说明 |
| --- | --- |
| 控制台 | [sentry.io](https://sentry.io) 或自建 |
| 服务 | 后端全服务 + iOS |
| Vault | `secret/data/prod-{cn,os}/global/platform/sentry` |

**开通步骤摘要：**

1. 创建 Organization，项目 `babycamera-api`、`babycamera-ios`。
2. 获取 DSN、Auth Token（CI 发布 release）。
3. 配置 PII  scrubbing（手机号、Token 脱敏，T7.8）。
4. 后端通过 Vault 注入 DSN；iOS 通过 xcconfig + CI。

**验证方法：**

- [ ] 故意触发示例异常，后端与 iOS 均收到事件
- [ ] Release 版本号与 Git SHA 关联

---

## 3. 凭据入库 Checklist

产线 Key **必须**经 Vault 写入，禁止通过 IM/邮件明文传递。

| 步骤 | 负责人 | 状态 |
| --- | --- | :---: |
| 在 Vault 创建对应 path（见 §1 表） | INFRA | - [ ] |
| 填入 `secrets-template/` 对应字段 | INFRA | - [ ] |
| 绑定 `policies/{service}.hcl` 到 K8s SA | INFRA | - [ ] |
| staging 滚动重启并跑 verification-checklist | BE + QA | - [ ] |
| 更新 §1 开通状态 checkbox | INFRA | - [ ] |
| 归档账号合同/备案到法务目录（不进 Git） | COMP | - [ ] |

---

## 4. 测试 Key vs 产线 Key 策略

| 环境 | 存储 | 用途 |
| --- | --- | --- |
| **dev** | Vault `secret/data/dev/...` 或开发者本地 `.env` | 个人调试，额度最小 |
| **staging** | Vault `secret/data/staging/...` | QA e2e、Mock 三方联调 |
| **prod-cn / prod-os** | Vault 产线路径 | 仅 K8s 运行时读取 |
| **iOS 端侧 SDK ID** | GitLab CI Protected + Masked | 构建时注入，非 Secret 的 AppID 可进 plist |

轮换流程见 [`../vault/README.md`](../vault/README.md) §5。

---

## 5. 文档验收（T0.12）

- [ ] §1 表覆盖 T0.12 要求的 **全部 14 类** 第三方
- [ ] 每类含开通步骤摘要 + 验证方法
- [ ] Vault path 与 `secrets-template/`、`policies/` 一致
- [ ] 无真实 API Key / 密码出现在仓库内
- [ ] `verification-checklist.md` 可逐项执行

**最后更新**：2026-06-06 · 任务 T0.12
