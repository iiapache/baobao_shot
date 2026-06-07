package router

import (
	"fmt"
	"math"
	"sort"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// RouteRequest describes inputs for adapter selection.
type RouteRequest struct {
	Region     model.Region
	Style      string
	Capability model.Capability
	Exclude    []string // failed adapters to skip (backup degradation)
}

// RouteResult is the selected adapter and selection rationale.
type RouteResult struct {
	Adapter adapter.ModelAdapter
	Reason  string
}

// ModelRouter selects an adapter by region, play whitelist, filing validity,
// load, and 5-minute success-rate sliding window (design-backend §5.3).
type ModelRouter struct {
	adapters map[string]adapter.ModelAdapter
	filings  map[string]adapter.FilingInfo
	plays    *PlayRegistry
	metrics  *MetricsStore
}

// NewModelRouter wires adapters, filing status, play whitelist, and metrics.
func NewModelRouter(
	adapters []adapter.ModelAdapter,
	filings map[string]adapter.FilingInfo,
	plays *PlayRegistry,
	metrics *MetricsStore,
) *ModelRouter {
	byName := make(map[string]adapter.ModelAdapter, len(adapters))
	for _, a := range adapters {
		byName[a.Name()] = a
	}
	if filings == nil {
		filings = make(map[string]adapter.FilingInfo)
	}
	if metrics == nil {
		metrics = NewMetricsStore()
	}
	return &ModelRouter{
		adapters: byName,
		filings:  filings,
		plays:    plays,
		metrics:  metrics,
	}
}

// Metrics exposes the metrics store for workers to report outcomes and load.
func (r *ModelRouter) Metrics() *MetricsStore {
	return r.metrics
}

// Route picks the best adapter for the request.
func (r *ModelRouter) Route(req RouteRequest) (RouteResult, error) {
	if req.Region != model.RegionCN && req.Region != model.RegionOS {
		return RouteResult{}, ErrInvalidRegion
	}

	play, ok := r.plays.Lookup(req.Region, req.Style)
	if !ok {
		return RouteResult{}, ErrPlayNotAvailable
	}
	if play.Capability != req.Capability {
		return RouteResult{}, ErrPlayNotAvailable
	}

	exclude := toSet(req.Exclude)
	candidates := make([]candidate, 0, len(play.AdapterNames))
	var filingBlocked int
	var eligibleWithoutFiling int
	for order, name := range play.AdapterNames {
		if exclude[name] {
			continue
		}
		a, exists := r.adapters[name]
		if !exists {
			continue
		}
		if a.Region() != req.Region {
			continue // hard region isolation: CN never OS, OS never CN
		}
		if !a.Supports(req.Capability) {
			continue
		}
		eligibleWithoutFiling++
		filing := r.filings[name]
		if !filing.IsValid(a.Region()) {
			filingBlocked++
			continue
		}
		candidates = append(candidates, candidate{
			adapter:      a,
			playOrder:    order,
			load:         r.metrics.Load(name),
			successRate:  r.metrics.SuccessRate(name),
		})
	}

	if len(candidates) == 0 {
		if filingBlocked > 0 && filingBlocked == eligibleWithoutFiling {
			return RouteResult{}, ErrModelFilingRequired
		}
		return RouteResult{}, ErrNoAdapterAvailable
	}

	sort.SliceStable(candidates, func(i, j int) bool {
		return candidateLess(candidates[i], candidates[j])
	})

	best := candidates[0]
	return RouteResult{
		Adapter: best.adapter,
		Reason: fmt.Sprintf(
			"region=%s play=%s success_rate=%.2f load=%d play_order=%d",
			req.Region, req.Style, best.successRate, best.load, best.playOrder,
		),
	}, nil
}

type candidate struct {
	adapter     adapter.ModelAdapter
	playOrder   int
	load        int64
	successRate float64
}

// Higher success rate wins; lower load wins; lower play order (primary) wins.
func candidateLess(a, b candidate) bool {
	if math.Abs(a.successRate-b.successRate) > 1e-9 {
		return a.successRate > b.successRate
	}
	if a.load != b.load {
		return a.load < b.load
	}
	return a.playOrder < b.playOrder
}

func toSet(items []string) map[string]bool {
	out := make(map[string]bool, len(items))
	for _, s := range items {
		out[s] = true
	}
	return out
}
