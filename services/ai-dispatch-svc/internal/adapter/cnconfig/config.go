package cnconfig

import (
	"os"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/jimeng"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/seedance"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/seedream"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/tongyi"
)

const (
	defaultDashScopeEndpoint = "https://dashscope.aliyuncs.com"
	defaultBytedanceEndpoint = "https://visual.volcengineapi.com"
)

// Settings holds CN adapter runtime settings loaded from environment variables.
type Settings struct {
	MockMode           bool
	DashScopeAPIKey    string
	DashScopeEndpoint  string
	WanxiangModelID    string
	BytedanceAPIKey    string
	BytedanceAPISecret string
	BytedanceEndpoint  string
	SeedreamModelID    string
	JimengModelID      string
	SeedanceModelID    string
	ObjectURLPrefix    string
}

// LoadFromEnv reads CN adapter settings from environment variables.
func LoadFromEnv() Settings {
	return Settings{
		MockMode:           strings.EqualFold(os.Getenv("CN_ADAPTER_MOCK_MODE"), "true"),
		DashScopeAPIKey:    os.Getenv("DASHSCOPE_API_KEY"),
		DashScopeEndpoint:  firstNonEmpty(os.Getenv("DASHSCOPE_ENDPOINT"), defaultDashScopeEndpoint),
		WanxiangModelID:    os.Getenv("WANXIANG_MODEL_ID"),
		BytedanceAPIKey:    firstNonEmpty(os.Getenv("BYTEDANCE_API_KEY"), os.Getenv("VOLCENGINE_API_KEY")),
		BytedanceAPISecret: firstNonEmpty(os.Getenv("BYTEDANCE_API_SECRET"), os.Getenv("VOLCENGINE_API_SECRET")),
		BytedanceEndpoint:  firstNonEmpty(os.Getenv("BYTEDANCE_ENDPOINT"), defaultBytedanceEndpoint),
		SeedreamModelID:    os.Getenv("SEEDREAM_MODEL_ID"),
		JimengModelID:      os.Getenv("JIMENG_MODEL_ID"),
		SeedanceModelID:    os.Getenv("SEEDANCE_MODEL_ID"),
		ObjectURLPrefix:    os.Getenv("OBJECT_URL_PREFIX"),
	}
}

// BuildCNAdapters constructs live or mock CN adapters from settings.
// ghibli_kid (CN) routes to SeedreamAdapter (Bytedance); photo_restore uses DashScope Tongyi.
func BuildCNAdapters(settings Settings) []adapter.ModelAdapter {
	mock := settings.MockMode
	if !mock &&
		strings.TrimSpace(settings.DashScopeAPIKey) == "" &&
		strings.TrimSpace(settings.BytedanceAPIKey) == "" {
		mock = true
	}

	bk := settings.BytedanceAPIKey
	bs := settings.BytedanceAPISecret
	be := strings.TrimRight(settings.BytedanceEndpoint, "/")
	dsEndpoint := strings.TrimRight(settings.DashScopeEndpoint, "/")
	objectPrefix := settings.ObjectURLPrefix

	return []adapter.ModelAdapter{
		seedream.NewAdapter(seedream.Config{
			MockMode:        mock,
			APIKey:          bk,
			APISecret:       bs,
			Endpoint:        be,
			ModelID:         settings.SeedreamModelID,
			ObjectURLPrefix: objectPrefix,
		}),
		tongyi.NewAdapter(tongyi.Config{
			MockMode:        mock,
			APIKey:          settings.DashScopeAPIKey,
			Endpoint:        dsEndpoint,
			ModelID:         settings.WanxiangModelID,
			ObjectURLPrefix: objectPrefix,
		}),
		jimeng.NewAdapter(jimeng.Config{
			MockMode:        mock,
			APIKey:          bk,
			APISecret:       bs,
			Endpoint:        be,
			ModelID:         settings.JimengModelID,
			ObjectURLPrefix: objectPrefix,
		}),
		seedance.NewAdapter(seedance.Config{
			MockMode:        mock,
			APIKey:          bk,
			APISecret:       bs,
			Endpoint:        be,
			ModelID:         settings.SeedanceModelID,
			ObjectURLPrefix: objectPrefix,
		}),
	}
}

// EnrichAdapters replaces CN stub adapters with configured CN adapters.
func EnrichAdapters(base []adapter.ModelAdapter) []adapter.ModelAdapter {
	cnAdapters := BuildCNAdapters(LoadFromEnv())

	byName := make(map[string]adapter.ModelAdapter, len(cnAdapters))
	for _, a := range cnAdapters {
		byName[a.Name()] = a
	}

	out := make([]adapter.ModelAdapter, 0, len(base)+len(cnAdapters))
	for _, a := range base {
		if replacement, ok := byName[a.Name()]; ok {
			out = append(out, replacement)
			delete(byName, a.Name())
			continue
		}
		out = append(out, a)
	}
	for _, a := range byName {
		out = append(out, a)
	}
	return out
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}
