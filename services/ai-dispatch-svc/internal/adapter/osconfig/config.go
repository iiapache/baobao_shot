package osconfig

import (
	"context"
	"os"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/gptimage2"
	"github.com/baobao/ai-dispatch-svc/internal/adapter/nanobanana"
	"github.com/baobao/ai-dispatch-svc/internal/configclient"
)

const (
	// FeatureOSTrainingOptOut is the config-svc flag for OS no-training contract (T7.4).
	FeatureOSTrainingOptOut = "compliance.os_training_opt_out"

	defaultOpenAIBase = "https://api.openai.com/v1"
	defaultGoogleBase = "https://aiplatform.googleapis.com"
)

// Settings holds OS adapter runtime settings loaded from env and config-svc.
type Settings struct {
	OpenAIBaseURL    string
	GoogleAPIBase    string
	OpenAIAPIKey     string
	OpenAIOrgID      string
	GoogleAPIKey     string
	GoogleProjectID  string
	GoogleLocation   string
	ObjectURLPrefix  string
	NoTrainingOptOut bool
	MockMode         bool
}

// LoadFromEnv reads OS compliance adapter settings from environment variables.
func LoadFromEnv() Settings {
	openAIBase := firstNonEmpty(
		os.Getenv("OPENAI_API_BASE"),
		os.Getenv("OPENAI_BASE_URL"),
		defaultOpenAIBase,
	)
	googleBase := firstNonEmpty(
		os.Getenv("GOOGLE_API_BASE"),
		os.Getenv("GOOGLE_ENDPOINT"),
		defaultGoogleBase,
	)

	noTraining := strings.EqualFold(os.Getenv("OPENAI_NO_TRAINING_HEADER"), "1") ||
		strings.EqualFold(os.Getenv("OPENAI_NO_TRAINING_HEADER"), "true") ||
		strings.EqualFold(os.Getenv("GOOGLE_NO_TRAINING_HEADER"), "1") ||
		strings.EqualFold(os.Getenv("GOOGLE_NO_TRAINING_HEADER"), "true")

	return Settings{
		OpenAIBaseURL:    strings.TrimRight(openAIBase, "/"),
		GoogleAPIBase:    strings.TrimRight(googleBase, "/"),
		OpenAIAPIKey:     os.Getenv("OPENAI_API_KEY"),
		OpenAIOrgID:      os.Getenv("OPENAI_ORG_ID"),
		GoogleAPIKey:     os.Getenv("GOOGLE_API_KEY"),
		GoogleProjectID:  os.Getenv("GOOGLE_PROJECT_ID"),
		GoogleLocation:   firstNonEmpty(os.Getenv("GOOGLE_LOCATION"), "us-central1"),
		ObjectURLPrefix:  os.Getenv("OBJECT_URL_PREFIX"),
		NoTrainingOptOut: noTraining,
		MockMode:         strings.EqualFold(os.Getenv("OS_ADAPTER_MOCK_MODE"), "true"),
	}
}

// ResolveNoTrainingOptOut merges env overrides with config-svc OS region flag.
func ResolveNoTrainingOptOut(ctx context.Context, env Settings, client configclient.Client) bool {
	if env.NoTrainingOptOut {
		return true
	}
	if client == nil {
		return false
	}
	features, err := client.Features(ctx, configclient.Request{Region: "os"})
	if err != nil {
		return false
	}
	if flag, ok := features[FeatureOSTrainingOptOut]; ok && flag.Enabled {
		return true
	}
	return false
}

// BuildOSAdapters constructs live or mock OS adapters from settings.
func BuildOSAdapters(settings Settings) []adapter.ModelAdapter {
	optOut := settings.NoTrainingOptOut
	mock := settings.MockMode

	gptKey := strings.TrimSpace(settings.OpenAIAPIKey)
	if !mock && gptKey == "" {
		mock = true
	}
	googleKey := strings.TrimSpace(settings.GoogleAPIKey)
	googleProject := strings.TrimSpace(settings.GoogleProjectID)
	if !mock && (googleKey == "" || googleProject == "") {
		mock = true
	}

	return []adapter.ModelAdapter{
		gptimage2.NewAdapter(gptimage2.Config{
			MockMode:         mock,
			APIKey:           settings.OpenAIAPIKey,
			OrgID:            settings.OpenAIOrgID,
			BaseURL:          settings.OpenAIBaseURL,
			ObjectURLPrefix:  settings.ObjectURLPrefix,
			NoTrainingOptOut: optOut,
		}),
		nanobanana.NewAdapter(nanobanana.Config{
			MockMode:         mock,
			APIKey:           settings.GoogleAPIKey,
			ProjectID:        settings.GoogleProjectID,
			Location:         settings.GoogleLocation,
			Endpoint:         settings.GoogleAPIBase,
			ObjectURLPrefix:  settings.ObjectURLPrefix,
			NoTrainingOptOut: optOut,
		}),
	}
}

// EnrichAdapters replaces OS stub adapters with configured OS adapters.
func EnrichAdapters(base []adapter.ModelAdapter, ctx context.Context, client configclient.Client) []adapter.ModelAdapter {
	settings := LoadFromEnv()
	settings.NoTrainingOptOut = ResolveNoTrainingOptOut(ctx, settings, client)
	osAdapters := BuildOSAdapters(settings)

	byName := make(map[string]adapter.ModelAdapter, len(osAdapters))
	for _, a := range osAdapters {
		byName[a.Name()] = a
	}

	out := make([]adapter.ModelAdapter, 0, len(base))
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
