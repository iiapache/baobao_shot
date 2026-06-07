package router

import (
	"errors"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestModelRouter_FilingRequiredErrorCode(t *testing.T) {
	router := NewModelRouter(testAdapters(), cnFilings(false), testPlayRegistry(), NewMetricsStore())
	_, err := router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "storybook_gen",
		Capability: model.CapabilityImageGen,
	})
	if !errors.Is(err, ErrModelFilingRequired) {
		t.Fatalf("error = %v, want ErrModelFilingRequired", err)
	}
	if ErrorCode(err) != CodeModelFilingRequired {
		t.Fatalf("code = %q, want %q", ErrorCode(err), CodeModelFilingRequired)
	}
}

func TestModelRouter_FilingValidAcceptsCN(t *testing.T) {
	router := NewModelRouter(testAdapters(), cnFilings(true), testPlayRegistry(), NewMetricsStore())
	result, err := router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "storybook_gen",
		Capability: model.CapabilityImageGen,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Name() != "SeedreamAdapter" {
		t.Fatalf("adapter = %s, want SeedreamAdapter", result.Adapter.Name())
	}
}

func TestModelRouter_PartialFilingFallsBack(t *testing.T) {
	filings := map[string]adapter.FilingInfo{
		"SeedreamAdapter":       {},
		"TongyiWanxiangAdapter": {GenAIFilingNo: "GAI-2", DeepSynthFilingNo: "DS-2"},
	}
	plays := NewPlayRegistry(PlayEntry{
		Style:        "dual_gen",
		Region:       model.RegionCN,
		Capability:   model.CapabilityImageGen,
		AdapterNames: []string{"SeedreamAdapter", "TongyiWanxiangAdapter"},
	})
	adapters := []adapter.ModelAdapter{
		&adapter.StubAdapter{
			AdapterName:   "SeedreamAdapter",
			AdapterRegion: model.RegionCN,
			Capabilities:  []model.Capability{model.CapabilityImageGen},
		},
		&adapter.StubAdapter{
			AdapterName:   "TongyiWanxiangAdapter",
			AdapterRegion: model.RegionCN,
			Capabilities:  []model.Capability{model.CapabilityImageGen},
		},
	}
	router := NewModelRouter(adapters, filings, plays, NewMetricsStore())
	result, err := router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "dual_gen",
		Capability: model.CapabilityImageGen,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Name() != "TongyiWanxiangAdapter" {
		t.Fatalf("adapter = %s, want backup with valid filing", result.Adapter.Name())
	}
}

func TestModelRouter_OSFilingExemptNoError(t *testing.T) {
	router := NewModelRouter(testAdapters(), map[string]adapter.FilingInfo{}, testPlayRegistry(), NewMetricsStore())
	_, err := router.Route(RouteRequest{
		Region:     model.RegionOS,
		Style:      "storybook_gen",
		Capability: model.CapabilityImageGen,
	})
	if err != nil {
		t.Fatalf("OS route should not require filing: %v", err)
	}
}
