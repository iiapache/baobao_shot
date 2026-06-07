package router

import "github.com/baobao/ai-dispatch-svc/internal/model"

// PlayEntry binds a style/play id to capability and adapter candidates for a region.
type PlayEntry struct {
	Style        string
	Region       model.Region
	Capability   model.Capability
	AdapterNames []string // primary-first order for tie-breaking
}

// PlayRegistry resolves play/style whitelist per region (design-backend §5.3).
type PlayRegistry struct {
	entries map[string]PlayEntry // key: region|style
}

// NewPlayRegistry builds a registry from play entries.
func NewPlayRegistry(entries ...PlayEntry) *PlayRegistry {
	r := &PlayRegistry{entries: make(map[string]PlayEntry, len(entries))}
	for _, e := range entries {
		r.entries[playKey(e.Region, e.Style)] = e
	}
	return r
}

// Lookup returns the play entry for region+style, or false if unavailable.
func (r *PlayRegistry) Lookup(region model.Region, style string) (PlayEntry, bool) {
	e, ok := r.entries[playKey(region, style)]
	return e, ok
}

func playKey(region model.Region, style string) string {
	return string(region) + "|" + style
}
