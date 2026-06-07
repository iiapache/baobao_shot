# 合规配置

## 单一数据源

| 文件 | 用途 |
| --- | --- |
| [`client-config.yaml`](./client-config.yaml) | ICP / 算法备案摘要 / 模型绑定（端侧 + config-svc） |
| [`algorithm-filing/filings.yaml`](./algorithm-filing/filings.yaml) | ai-dispatch-svc 模型备案号绑定 |

## 同步

```bash
python3 scripts/sync-compliance-config.py
```

生成 `ios/Packages/BabyCameraSettings/Resources/ComplianceBundledConfig.json`，并打印 config-svc seed 值。修改 `client-config.yaml` 后需同步更新 `filings.yaml` 与 `services/*/config-svc/internal/store/memory.go`。

## 状态

- `status: staging` — 正式号获批前；ICP 后缀 `-9S` 表示 staging
- `status: production` — 管局/网信办正式号回填后替换字段值即可
