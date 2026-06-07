package worker

import (
	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/filing"
	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/baobao/ai-dispatch-svc/internal/router"
)

// BuildDevRouter wires stub adapters and play whitelist for local worker execution.
func BuildDevRouter(adapters []adapter.ModelAdapter, filings filing.Bindings) *router.ModelRouter {
	if adapters == nil {
		adapters = DefaultDevAdapters()
	}
	if filings == nil {
		filings = filing.DevBindings()
	}
	plays := router.NewPlayRegistry(
		router.PlayEntry{Style: "ghibli_kid", Region: model.RegionCN, Capability: model.CapabilityImageGen, AdapterNames: []string{"SeedreamAdapter", "TongyiWanxiangAdapter"}},
		router.PlayEntry{Style: "ghibli_kid", Region: model.RegionOS, Capability: model.CapabilityImageGen, AdapterNames: []string{"GptImage2Adapter", "NanoBananaAdapter"}},
		router.PlayEntry{Style: "seedream_style", Region: model.RegionCN, Capability: model.CapabilityImageGen, AdapterNames: []string{"SeedreamAdapter"}},
		router.PlayEntry{Style: "photo_restore", Region: model.RegionCN, Capability: model.CapabilityImageEdit, AdapterNames: []string{"TongyiWanxiangAdapter", "JimengAdapter"}},
		router.PlayEntry{Style: "photo_restore", Region: model.RegionOS, Capability: model.CapabilityImageEdit, AdapterNames: []string{"NanoBananaAdapter", "GptImage2Adapter"}},
		router.PlayEntry{Style: "video_walk", Region: model.RegionCN, Capability: model.CapabilityVideoGen, AdapterNames: []string{"SeedanceAdapter"}},
		router.PlayEntry{Style: "video_walk", Region: model.RegionOS, Capability: model.CapabilityVideoGen, AdapterNames: []string{"SeedanceAdapter"}},
	)
	return router.NewModelRouter(adapters, filings, plays, router.NewMetricsStore())
}

// DefaultDevAdapters returns pass-through stub adapters for dev worker runs.
func DefaultDevAdapters() []adapter.ModelAdapter {
	return []adapter.ModelAdapter{
		&adapter.StubAdapter{AdapterName: "SeedreamAdapter", AdapterRegion: model.RegionCN, Capabilities: []model.Capability{model.CapabilityImageGen}},
		&adapter.StubAdapter{AdapterName: "TongyiWanxiangAdapter", AdapterRegion: model.RegionCN, Capabilities: []model.Capability{model.CapabilityImageEdit}},
		&adapter.StubAdapter{AdapterName: "JimengAdapter", AdapterRegion: model.RegionCN, Capabilities: []model.Capability{model.CapabilityImageEdit}},
		&adapter.StubAdapter{AdapterName: "SeedanceAdapter", AdapterRegion: model.RegionCN, Capabilities: []model.Capability{model.CapabilityVideoGen}},
		&adapter.StubAdapter{AdapterName: "NanoBananaAdapter", AdapterRegion: model.RegionOS, Capabilities: []model.Capability{model.CapabilityImageEdit}},
		&adapter.StubAdapter{AdapterName: "GptImage2Adapter", AdapterRegion: model.RegionOS, Capabilities: []model.Capability{model.CapabilityImageEdit, model.CapabilityImageGen}},
	}
}
