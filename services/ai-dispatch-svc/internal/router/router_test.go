package router

import (
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestMetricsStore_SuccessRateSlidingWindow(t *testing.T) {
	m := NewMetricsStore()
	base := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	m.SetClock(func() time.Time { return base })

	m.RecordOutcome("A", true)
	m.RecordOutcome("A", false)
	if rate := m.SuccessRate("A"); rate != 0.5 {
		t.Fatalf("SuccessRate = %v, want 0.5", rate)
	}

	// Events older than 5min are pruned.
	m.SetClock(func() time.Time { return base.Add(6 * time.Minute) })
	if rate := m.SuccessRate("A"); rate != 1.0 {
		t.Fatalf("SuccessRate after window expiry = %v, want 1.0 (cold start)", rate)
	}

	m.RecordOutcome("A", false)
	m.RecordOutcome("A", false)
	m.RecordOutcome("A", true)
	if rate := m.SuccessRate("A"); rate != 1.0/3.0 {
		t.Fatalf("SuccessRate = %v, want ~0.33", rate)
	}
}

func TestMetricsStore_Load(t *testing.T) {
	m := NewMetricsStore()
	if got := m.Load("X"); got != 0 {
		t.Fatalf("Load() = %d, want 0", got)
	}
	m.SetLoad("X", 7)
	if got := m.Load("X"); got != 7 {
		t.Fatalf("Load() = %d, want 7", got)
	}
}

func cnFilings(valid bool) map[string]adapter.FilingInfo {
	if valid {
		return map[string]adapter.FilingInfo{
			"SeedreamAdapter":       {GenAIFilingNo: "GAI-1", DeepSynthFilingNo: "DS-1"},
			"TongyiWanxiangAdapter": {GenAIFilingNo: "GAI-2", DeepSynthFilingNo: "DS-2"},
		}
	}
	return map[string]adapter.FilingInfo{
		"SeedreamAdapter":       {},
		"TongyiWanxiangAdapter": {},
	}
}

func testAdapters() []adapter.ModelAdapter {
	return []adapter.ModelAdapter{
		&adapter.StubAdapter{
			AdapterName:   "SeedreamAdapter",
			AdapterRegion: model.RegionCN,
			Capabilities:  []model.Capability{model.CapabilityImageGen},
		},
		&adapter.StubAdapter{
			AdapterName:   "TongyiWanxiangAdapter",
			AdapterRegion: model.RegionCN,
			Capabilities:  []model.Capability{model.CapabilityImageEdit},
		},
		&adapter.StubAdapter{
			AdapterName:   "NanoBananaAdapter",
			AdapterRegion: model.RegionOS,
			Capabilities:  []model.Capability{model.CapabilityImageEdit},
		},
		&adapter.StubAdapter{
			AdapterName:   "GptImage2Adapter",
			AdapterRegion: model.RegionOS,
			Capabilities:  []model.Capability{model.CapabilityImageEdit, model.CapabilityImageGen},
		},
	}
}

func testPlayRegistry() *PlayRegistry {
	return NewPlayRegistry(
		PlayEntry{
			Style:        "storybook_gen",
			Region:       model.RegionCN,
			Capability:   model.CapabilityImageGen,
			AdapterNames: []string{"SeedreamAdapter", "TongyiWanxiangAdapter"},
		},
		PlayEntry{
			Style:        "style_swap",
			Region:       model.RegionCN,
			Capability:   model.CapabilityImageEdit,
			AdapterNames: []string{"TongyiWanxiangAdapter", "SeedreamAdapter"},
		},
		PlayEntry{
			Style:        "cartoon_edit",
			Region:       model.RegionOS,
			Capability:   model.CapabilityImageEdit,
			AdapterNames: []string{"NanoBananaAdapter", "GptImage2Adapter"},
		},
		PlayEntry{
			Style:        "storybook_gen",
			Region:       model.RegionOS,
			Capability:   model.CapabilityImageGen,
			AdapterNames: []string{"GptImage2Adapter", "NanoBananaAdapter"},
		},
	)
}

func TestModelRouter_CNNeverRoutesToOS(t *testing.T) {
	metrics := NewMetricsStore()
	// Make OS adapter look much healthier — must still pick CN.
	metrics.SetLoad("NanoBananaAdapter", 0)
	metrics.SetLoad("SeedreamAdapter", 999)
	for i := 0; i < 10; i++ {
		metrics.RecordOutcome("NanoBananaAdapter", true)
		metrics.RecordOutcome("SeedreamAdapter", false)
	}

	router := NewModelRouter(testAdapters(), cnFilings(true), testPlayRegistry(), metrics)

	result, err := router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "storybook_gen",
		Capability: model.CapabilityImageGen,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Name() != "SeedreamAdapter" {
		t.Fatalf("adapter = %s, want SeedreamAdapter (CN isolation)", result.Adapter.Name())
	}
	if result.Adapter.Region() != model.RegionCN {
		t.Fatalf("adapter region = %s, want cn", result.Adapter.Region())
	}
}

func TestModelRouter_OSRoutesToOSOnly(t *testing.T) {
	router := NewModelRouter(testAdapters(), cnFilings(true), testPlayRegistry(), NewMetricsStore())

	result, err := router.Route(RouteRequest{
		Region:     model.RegionOS,
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageEdit,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Region() != model.RegionOS {
		t.Fatalf("adapter region = %s, want os", result.Adapter.Region())
	}
}

func TestModelRouter_PlayNotAvailable(t *testing.T) {
	router := NewModelRouter(testAdapters(), cnFilings(true), testPlayRegistry(), NewMetricsStore())

	_, err := router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "unknown_play",
		Capability: model.CapabilityImageGen,
	})
	if err != ErrPlayNotAvailable {
		t.Fatalf("error = %v, want ErrPlayNotAvailable", err)
	}

	_, err = router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "storybook_gen",
		Capability: model.CapabilityImageEdit, // wrong capability for play
	})
	if err != ErrPlayNotAvailable {
		t.Fatalf("capability mismatch error = %v, want ErrPlayNotAvailable", err)
	}
}

func TestModelRouter_InvalidRegion(t *testing.T) {
	router := NewModelRouter(testAdapters(), cnFilings(true), testPlayRegistry(), NewMetricsStore())
	_, err := router.Route(RouteRequest{
		Region:     model.Region("xx"),
		Style:      "storybook_gen",
		Capability: model.CapabilityImageGen,
	})
	if err != ErrInvalidRegion {
		t.Fatalf("error = %v, want ErrInvalidRegion", err)
	}
}

func TestModelRouter_FilingInvalidExcludesCNAdapter(t *testing.T) {
	metrics := NewMetricsStore()
	router := NewModelRouter(testAdapters(), cnFilings(false), testPlayRegistry(), metrics)

	_, err := router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "storybook_gen",
		Capability: model.CapabilityImageGen,
	})
	if err != ErrModelFilingRequired {
		t.Fatalf("error = %v, want ErrModelFilingRequired when filing invalid", err)
	}
	if ErrorCode(err) != CodeModelFilingRequired {
		t.Fatalf("error code = %q, want %q", ErrorCode(err), CodeModelFilingRequired)
	}

	// Tongyi on style_swap has valid filing slot but wrong capability for image-gen play;
	// for image-edit play with invalid filing, also no adapter.
	_, err = router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "style_swap",
		Capability: model.CapabilityImageEdit,
	})
	if err != ErrModelFilingRequired {
		t.Fatalf("error = %v, want ErrModelFilingRequired", err)
	}
}

func TestModelRouter_PrefersHigherSuccessRate(t *testing.T) {
	metrics := NewMetricsStore()
	for i := 0; i < 9; i++ {
		metrics.RecordOutcome("NanoBananaAdapter", true)
	}
	for i := 0; i < 9; i++ {
		metrics.RecordOutcome("GptImage2Adapter", false)
	}
	metrics.SetLoad("NanoBananaAdapter", 1)
	metrics.SetLoad("GptImage2Adapter", 1)

	router := NewModelRouter(testAdapters(), cnFilings(true), testPlayRegistry(), metrics)
	result, err := router.Route(RouteRequest{
		Region:     model.RegionOS,
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageEdit,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Name() != "NanoBananaAdapter" {
		t.Fatalf("adapter = %s, want NanoBananaAdapter (higher success rate)", result.Adapter.Name())
	}
}

func TestModelRouter_PrefersLowerLoadOnEqualSuccessRate(t *testing.T) {
	metrics := NewMetricsStore()
	metrics.SetLoad("NanoBananaAdapter", 50)
	metrics.SetLoad("GptImage2Adapter", 2)

	router := NewModelRouter(testAdapters(), cnFilings(true), testPlayRegistry(), metrics)
	result, err := router.Route(RouteRequest{
		Region:     model.RegionOS,
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageEdit,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Name() != "GptImage2Adapter" {
		t.Fatalf("adapter = %s, want GptImage2Adapter (lower load)", result.Adapter.Name())
	}
}

func TestModelRouter_ExcludeFallbackToBackup(t *testing.T) {
	metrics := NewMetricsStore()
	filings := map[string]adapter.FilingInfo{
		"TongyiWanxiangAdapter": {GenAIFilingNo: "GAI-2", DeepSynthFilingNo: "DS-2"},
		"SeedreamAdapter":       {GenAIFilingNo: "GAI-1", DeepSynthFilingNo: "DS-1"},
	}

	router := NewModelRouter(testAdapters(), filings, testPlayRegistry(), metrics)
	_, err := router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "style_swap",
		Capability: model.CapabilityImageEdit,
		Exclude:    []string{"TongyiWanxiangAdapter"},
	})
	// Seedream is backup in whitelist but lacks image-edit capability.
	if err != ErrNoAdapterAvailable {
		t.Fatalf("error = %v, want ErrNoAdapterAvailable", err)
	}
}

func TestModelRouter_ExcludeWithCapableBackup(t *testing.T) {
	adapters := []adapter.ModelAdapter{
		&adapter.StubAdapter{
			AdapterName:   "PrimaryCN",
			AdapterRegion: model.RegionCN,
			Capabilities:  []model.Capability{model.CapabilityImageGen},
		},
		&adapter.StubAdapter{
			AdapterName:   "BackupCN",
			AdapterRegion: model.RegionCN,
			Capabilities:  []model.Capability{model.CapabilityImageGen},
		},
	}
	filings := map[string]adapter.FilingInfo{
		"PrimaryCN": {GenAIFilingNo: "G1", DeepSynthFilingNo: "D1"},
		"BackupCN":  {GenAIFilingNo: "G2", DeepSynthFilingNo: "D2"},
	}
	plays := NewPlayRegistry(PlayEntry{
		Style:        "dual_gen",
		Region:       model.RegionCN,
		Capability:   model.CapabilityImageGen,
		AdapterNames: []string{"PrimaryCN", "BackupCN"},
	})
	metrics := NewMetricsStore()
	metrics.SetLoad("PrimaryCN", 0)
	metrics.SetLoad("BackupCN", 0)

	router := NewModelRouter(adapters, filings, plays, metrics)
	result, err := router.Route(RouteRequest{
		Region:     model.RegionCN,
		Style:      "dual_gen",
		Capability: model.CapabilityImageGen,
		Exclude:    []string{"PrimaryCN"},
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Name() != "BackupCN" {
		t.Fatalf("adapter = %s, want BackupCN", result.Adapter.Name())
	}
}

func TestModelRouter_CapabilityMismatchInWhitelistSkipped(t *testing.T) {
	filings := map[string]adapter.FilingInfo{
		"SeedreamAdapter": {GenAIFilingNo: "GAI-1", DeepSynthFilingNo: "DS-1"},
	}
	router := NewModelRouter(testAdapters(), filings, testPlayRegistry(), NewMetricsStore())

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

func TestModelRouter_PlayOrderTieBreak(t *testing.T) {
	metrics := NewMetricsStore()
	router := NewModelRouter(testAdapters(), cnFilings(true), testPlayRegistry(), metrics)

	result, err := router.Route(RouteRequest{
		Region:     model.RegionOS,
		Style:      "cartoon_edit",
		Capability: model.CapabilityImageEdit,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Name() != "NanoBananaAdapter" {
		t.Fatalf("adapter = %s, want NanoBananaAdapter (primary play order)", result.Adapter.Name())
	}
}

func TestModelRouter_OSFilingExempt(t *testing.T) {
	// OS adapters have no filing entries but should still route.
	router := NewModelRouter(testAdapters(), map[string]adapter.FilingInfo{}, testPlayRegistry(), NewMetricsStore())
	result, err := router.Route(RouteRequest{
		Region:     model.RegionOS,
		Style:      "storybook_gen",
		Capability: model.CapabilityImageGen,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Region() != model.RegionOS {
		t.Fatalf("region = %s, want os", result.Adapter.Region())
	}
}

func TestFilingInfo_IsValid(t *testing.T) {
	cases := []struct {
		name   string
		filing adapter.FilingInfo
		region model.Region
		want   bool
	}{
		{"cn both numbers", adapter.FilingInfo{GenAIFilingNo: "g", DeepSynthFilingNo: "d"}, model.RegionCN, true},
		{"cn missing gen", adapter.FilingInfo{DeepSynthFilingNo: "d"}, model.RegionCN, false},
		{"cn missing deep", adapter.FilingInfo{GenAIFilingNo: "g"}, model.RegionCN, false},
		{"os exempt empty", adapter.FilingInfo{}, model.RegionOS, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := tc.filing.IsValid(tc.region); got != tc.want {
				t.Fatalf("IsValid() = %v, want %v", got, tc.want)
			}
		})
	}
}
