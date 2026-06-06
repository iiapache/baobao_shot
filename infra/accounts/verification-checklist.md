# 第三方账号连通性验证清单

> 占位脚本与 curl 命令，用于 **staging** 环境验收。  
> 执行前：`export VAULT_ADDR=...` 并从 Vault 拉取测试 Key，**勿将 Key 写入本文件**。

---

## 使用说明

```bash
# 通用：从 Vault 导出 staging 凭据到临时文件（示例）
vault kv get -format=json secret/staging/cn/auth-family/aliyun-sms \
  | jq -r '.data.data' > /tmp/aliyun-sms.env
set -a && source /tmp/aliyun-sms.env && set +a

# 跑单个章节
bash infra/accounts/scripts/verify-aliyun-sms.sh   # 待实现时可复制下方 curl
```

| 章节 | 对应账号 | 预期 |
| --- | --- | --- |
| §1 | Apple Developer / APNs | HTTP 200 |
| §2 | 阿里云短信 | 发送成功 BizId |
| §3 | 阿里云内容安全 | pass/block 符合样本 |
| §4 | AI 模型（字节/阿里/OpenAI/Google） | 各 1 次成功调用 |
| §5 | 广告（穿山甲/优量汇/AdMob） | 验签通过 |
| §6 | 百度网盘 OpenAPI | OAuth + 上传 |
| §7 | 微信开放平台 | token 接口 |
| §8 | Bugly / Sentry | 测试事件可见 |

---

## §1 Apple — APNs 推送测试

```bash
# 前置：从 Vault 读取 APNs .p8 相关变量
# APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC, APNS_PRIVATE_KEY_PEM

# 生成 JWT（需 jq + openssl，或使用 staging 内置工具）
# 占位：使用 auth-family 或 notification 服务 health + 内部 /debug/apns-ping

curl -sS -o /dev/null -w "%{http_code}" \
  -X POST "https://api.staging.internal/v1/debug/apns-ping" \
  -H "Authorization: Bearer ${STAGING_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"device_token":"REPLACE_DEVICE_TOKEN","title":"T0.12","body":"APNs smoke test"}'
# 期望: 200
```

**Checklist：**

- [ ] 沙盒 device token 收到推送
- [ ] 产线 APNs Key 仅来自 Vault path `.../notification/apns`

---

## §2 阿里云短信

```bash
# 占位：阿里云 RPC 签名较复杂，推荐 staging 调 auth-family API

curl -sS -X POST "https://api-cn.staging.example.com/v1/auth/phone/code" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","region":"cn"}'
# 期望: 200 + {"expiresIn":300}

# 直接调阿里云（需自行计算 Signature，仅作参考占位）
# Action=SendSms&PhoneNumbers=...&SignName=...&TemplateCode=...
# curl "https://dysmsapi.aliyuncs.com/?..." 
```

**Checklist：**

- [ ] 测试手机号收到验证码
- [ ] 60s 内重复请求被限流

---

## §3 阿里云内容安全

```bash
# 通过 audit-svc staging 代理（推荐）
curl -sS -X POST "https://api-cn.staging.example.com/v1/debug/audit/image" \
  -H "Authorization: Bearer ${STAGING_ADMIN_TOKEN}" \
  -F "file=@./fixtures/safe-image.jpg"
# 期望: {"result":"pass"}

curl -sS -X POST "https://api-cn.staging.example.com/v1/debug/audit/image" \
  -H "Authorization: Bearer ${STAGING_ADMIN_TOKEN}" \
  -F "file=@./fixtures/block-sample.jpg"
# 期望: {"result":"block"}
```

**Checklist：**

- [ ] 入参审核延迟 ≤3s（P95）
- [ ] Vault path `.../audit/aliyun-green` 可读

---

## §4 AI 模型厂商

### 4.1 字节 / 火山（Seedream）

```bash
curl -sS -X POST "https://api-cn.staging.example.com/v1/debug/ai/seedream" \
  -H "Authorization: Bearer ${STAGING_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"测试图片","width":512,"height":512}'
# 期望: 200 + taskId 或 imageUrl
```

### 4.2 阿里 DashScope（通义万相）

```bash
# 直连占位（Key 从环境变量 DASHSCOPE_API_KEY 读取，勿硬编码）
curl -sS -X POST "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis" \
  -H "Authorization: Bearer ${DASHSCOPE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"wanx-v1","input":{"prompt":"测试"},"parameters":{"size":"512*512"}}'
# 期望: HTTP 200 或异步 task_id
```

### 4.3 OpenAI（OS staging）

```bash
curl -sS -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-image-1","prompt":"test","size":"512x512","n":1}'
# 期望: 200；确认 Organization 未用于训练
```

### 4.4 Google Vertex / AI Studio（OS staging）

```bash
curl -sS -X POST \
  "https://${GOOGLE_LOCATION}-aiplatform.googleapis.com/v1/projects/${GOOGLE_PROJECT_ID}/locations/${GOOGLE_LOCATION}/publishers/google/models/gemini-2.0-flash-exp:generateContent" \
  -H "Authorization: Bearer ${GOOGLE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"role":"user","parts":[{"text":"ping"}]}]}'
# 期望: 200；或使用 API Key 端点等价调用
```

**Checklist：**

- [ ] CN staging 仅能通过 CN 模型 path
- [ ] OS staging OpenAI/Google path 与 prod-os Vault 一致
- [ ] 备案号缺失时 ai-dispatch 拒绝路由（T7.1，产线）

---

## §5 广告联盟 Server 验签

### 5.1 穿山甲激励回调（mock）

```bash
# 占位：使用 credit-sub-ad staging mock 端点
curl -sS -X POST "https://api-cn.staging.example.com/v1/credits/ad-reward/pangle/callback" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-uuid",
    "trans_id": "mock-trans-001",
    "sign": "REPLACE_COMPUTED_SIGN",
    "extra": "{}"
  }'
# 期望: 200 + credits granted；错误 sign → 403
```

### 5.2 优量汇

```bash
curl -sS -X POST "https://api-cn.staging.example.com/v1/credits/ad-reward/gdt/callback" \
  -H "Content-Type: application/json" \
  -d '{"sig":"REPLACE","userid":"test","transid":"mock-002"}'
# 期望: 验签逻辑与 Vault GDT_SECRET_KEY 一致
```

### 5.3 AdMob SSV（OS）

```bash
# Google 公钥验证 — 占位 URL
curl -sS "https://www.gstatic.com/admob/reward/verifier-keys.json" | jq '.keys | length'
# 期望: >= 1

curl -sS -X POST "https://api-os.staging.example.com/v1/credits/ad-reward/admob/callback" \
  -G --data-urlencode "ad_network=..." \
  --data-urlencode "reward_amount=1" \
  --data-urlencode "signature=REPLACE" \
  --data-urlencode "key_id=REPLACE"
# 期望: 200
```

**Checklist：**

- [ ] 伪造签名被拒绝
- [ ] 单日激励 ≤5 次

---

## §6 百度网盘 OpenAPI

```bash
# Step 1: 授权 URL（浏览器打开）
echo "https://openapi.baidu.com/oauth/2.0/authorize?response_type=code&client_id=${BAIDU_PAN_APP_KEY}&redirect_uri=${BAIDU_PAN_REDIRECT_URI}&scope=basic,netdisk"

# Step 2: code 换 token（占位）
curl -sS -X POST "https://openapi.baidu.com/oauth/2.0/token" \
  -d "grant_type=authorization_code" \
  -d "code=REPLACE_AUTH_CODE" \
  -d "client_id=${BAIDU_PAN_APP_KEY}" \
  -d "client_secret=${BAIDU_PAN_SECRET_KEY}" \
  -d "redirect_uri=${BAIDU_PAN_REDIRECT_URI}"
# 期望: access_token + refresh_token

# Step 3: 预上传（分片）占位
curl -sS -X POST "https://pan.baidu.com/rest/2.0/xpan/file?method=precreate" \
  -H "User-Agent: pan.baidu.com" \
  -d "access_token=${BAIDU_ACCESS_TOKEN}" \
  -d "path=/apps/babycamera/test/smoke.txt" \
  -d "size=4" \
  -d "isdir=0" \
  -d "autoinit=1" \
  -d "block_list=[\"$(echo -n test | md5)\"]"
# 期望: return_type=0
```

**Checklist：**

- [ ] OAuth 闭环
- [ ] client secret 来自 Vault；user token 落库加密

---

## §7 微信开放平台

```bash
# 获取 access_token（AppSecret 从 Vault，勿写入命令历史）
curl -sS "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${WECHAT_APP_ID}&secret=${WECHAT_APP_SECRET}"
# 期望: {"access_token":"...","expires_in":7200}

# 检查 API 域名可达
curl -sS -o /dev/null -w "%{http_code}" "https://api.weixin.qq.com/cgi-bin/getcallbackip?access_token=INVALID"
# 期望: 200（body 含 errcode 40001 表示 token 无效但链路通）
```

**Checklist：**

- [ ] 移动应用审核状态允许调试
- [ ] Universal Link 与 Bundle ID 匹配

---

## §8 可观测性 — Bugly & Sentry

### 8.1 Sentry 后端

```bash
curl -sS -X POST "https://o0000000.ingest.sentry.io/api/0000000/store/" \
  -H "X-Sentry-Auth: Sentry sentry_key=${SENTRY_PUBLIC_KEY}, sentry_version=7" \
  -H "Content-Type: application/json" \
  -d '{"message":"T0.12 smoke test","level":"error","platform":"go"}'
# 期望: HTTP 200；事件出现在 Sentry 项目
```

### 8.2 Sentry iOS（经 staging 调试接口）

```bash
curl -sS -X POST "https://api.staging.internal/v1/debug/sentry-ping" \
  -H "Authorization: Bearer ${STAGING_ADMIN_TOKEN}"
# 期望: 200
```

### 8.3 Bugly

```bash
# Bugly 无标准 REST smoke；通过 TestFlight 构建触发测试崩溃
# CI 符号表上传占位：
# curl -F "file=@app.dSYM.zip" -F "appId=${BUGLY_APP_ID}" ...
echo "Manual: 安装 staging 包 → 触发测试崩溃 → Bugly 控制台 5min 内可见"
```

**Checklist：**

- [ ] Sentry DSN 来自 Vault `.../platform/sentry`
- [ ] 日志中无 Token/手机号明文（T7.8）

---

## §9 总验收签字表

| 项 | 执行人 | 日期 | 结果 |
| --- | --- | --- | --- |
| §1 Apple / APNs | | | - [ ] Pass |
| §2 阿里云短信 | | | - [ ] Pass |
| §3 阿里云内容安全 | | | - [ ] Pass |
| §4 AI 模型（4 厂商） | | | - [ ] Pass |
| §5 广告（3 联盟） | | | - [ ] Pass |
| §6 百度网盘 | | | - [ ] Pass |
| §7 微信开放平台 | | | - [ ] Pass |
| §8 Bugly + Sentry | | | - [ ] Pass |
| 产线 Key 全在 Vault | INFRA | | - [ ] Pass |
| 仓库无真实密钥 | QA | | - [ ] Pass |

---

**关联文档**：[`THIRD_PARTY_ACCOUNTS.md`](./THIRD_PARTY_ACCOUNTS.md) · [`../vault/README.md`](../vault/README.md)
