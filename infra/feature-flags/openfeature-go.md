# OpenFeature Go 接入指南

> 可选方案：当运营需要频繁改 flag 时，从 `config-svc` 静态种子迁移到 Unleash Provider。

## 依赖

```bash
go get github.com/open-feature/go-sdk/pkg/openfeature
go get github.com/Unleash/unleash-client-go/v4
```

## 与 config-svc 分桶对齐

迁移前确保 Unleash 策略与 `config-svc` 使用相同上下文：

```go
package featurectx

import (
	"hash/fnv"

	"github.com/open-feature/go-sdk/pkg/openfeature"
)

// UserIDHash 与 config-svc/internal/feature/hash.go 保持一致。
func UserIDHash(userID string) int {
	if userID == "" {
		return 0
	}
	h := fnv.New32a()
	_, _ = h.Write([]byte(userID))
	return int(h.Sum32() % 100)
}

func EvaluationContext(region, userID, appVersion string) openfeature.EvaluationContext {
	return openfeature.NewEvaluationContext(
		userID,
		map[string]interface{}{
			"region":      region,
			"userIdHash":  UserIDHash(userID),
			"appVersion":  appVersion,
		},
	)
}
```

## Unleash Provider 初始化（占位）

```go
package main

import (
	"log"
	"net/http"
	"os"

	"github.com/Unleash/unleash-client-go/v4"
	"github.com/open-feature/go-sdk/pkg/openfeature"
)

func initUnleash() {
	_ = unleash.Initialize(
		unleash.WithListener(&unleash.DebugListener{}),
		unleash.WithAppName("config-svc"),
		unleash.WithUrl(os.Getenv("UNLEASH_URL")),
		unleash.WithCustomHeaders(http.Header{
			"Authorization": []string{os.Getenv("UNLEASH_API_TOKEN")},
		}),
	)
	// TODO: 注册 OpenFeature Unleash Provider（社区 provider 或自建）
	_ = openfeature.SetProvider(nil)
}

func isEnabled(flag, region, userID, appVersion string) bool {
	client := openfeature.NewClient("baobao-go")
	ctx := EvaluationContext(region, userID, appVersion)
	val, _ := client.GetBooleanValue(ctx, flag, false)
	return val
}
```

## Unleash 策略建议

在 Admin UI 为每个 flag 配置：

1. **Region 约束**：`region` in `cn` / `os`
2. **渐进发布**：`userIdHash` gradual rollout（0–100%）
3. **版本门槛**：`appVersion` >= `x.y.z`

## 回退策略

| 场景 | 行为 |
| --- | --- |
| Unleash 不可用 | 回退 `config-svc` REST 缓存（TTL 300s） |
| 首次冷启动 | 使用 `MemoryStore` 种子默认值 |

## 环境变量

| 变量 | 示例 |
| --- | --- |
| `UNLEASH_URL` | `http://localhost:4242/api` |
| `UNLEASH_API_TOKEN` | `*:development.unleash-insecure-api-token` |

## 参考

- [OpenFeature Go SDK](https://openfeature.dev/docs/reference/technologies/server/go)
- [Unleash Go Client](https://docs.getunleash.io/reference/sdks/go)
