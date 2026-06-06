# ai-dispatch-svc 最小权限策略
# 职责：国内/海外 AI 模型 API Key、OSS/S3 临时凭证（如经 media-svc STS 则无需此处）

# dev / staging
path "secret/data/dev/cn/ai-dispatch/*" {
  capabilities = ["read"]
}
path "secret/data/dev/os/ai-dispatch/*" {
  capabilities = ["read"]
}
path "secret/data/staging/cn/ai-dispatch/*" {
  capabilities = ["read"]
}
path "secret/data/staging/os/ai-dispatch/*" {
  capabilities = ["read"]
}

# 产线 CN：字节（Seedream/Jimeng/Seedance）、阿里通义
path "secret/data/prod-cn/cn/ai-dispatch/bytedance" {
  capabilities = ["read"]
}
path "secret/data/prod-cn/cn/ai-dispatch/alibaba-dashscope" {
  capabilities = ["read"]
}

# 产线 OS：OpenAI、Google
path "secret/data/prod-os/os/ai-dispatch/openai" {
  capabilities = ["read"]
}
path "secret/data/prod-os/os/ai-dispatch/google" {
  capabilities = ["read"]
}

# 算法备案号配置（T7.1）
path "secret/data/prod-cn/cn/ai-dispatch/model-filing" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/shared/mongodb-ai-dispatch" {
  capabilities = ["read"]
}
path "secret/data/prod-cn/cn/shared/kafka-ai-dispatch" {
  capabilities = ["read"]
}

# CN 服务禁止读 OS 模型 Key
path "secret/data/prod-os/os/ai-dispatch/*" {
  capabilities = ["deny"]
}
