package filing

import (
	"log/slog"
	"sort"
	"strings"
	"sync"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// Store holds CN model filing bindings with optional hot reload.
type Store struct {
	mu      sync.RWMutex
	source  string
	entries Bindings
}

// NewStore creates a filing registry.
func NewStore(entries Bindings, source string) *Store {
	if entries == nil {
		entries = make(Bindings)
	}
	return &Store{entries: entries, source: source}
}

// Reload replaces bindings (e.g. config-svc hot update).
func (s *Store) Reload(entries Bindings, source string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if entries == nil {
		entries = make(Bindings)
	}
	s.entries = entries
	if source != "" {
		s.source = source
	}
}

// Source returns the last load source label.
func (s *Store) Source() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.source
}

// Bindings returns a snapshot of adapter filing info.
func (s *Store) Bindings() Bindings {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return cloneBindings(s.entries)
}

// Lookup returns filing info for an adapter.
func (s *Store) Lookup(adapterName string) (adapter.FilingInfo, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	info, ok := s.entries[adapterName]
	return info, ok
}

// PlayRoutableInCN reports whether a CN play has at least one filed adapter.
func (s *Store) PlayRoutableInCN(playID string) bool {
	adapters, ok := CNPlayAdapters[playID]
	if !ok {
		return true
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, name := range adapters {
		if info, exists := s.entries[name]; exists && info.IsValid(model.RegionCN) {
			return true
		}
	}
	return false
}

// LogBindings prints a startup summary with masked filing numbers.
func (s *Store) LogBindings() {
	s.mu.RLock()
	defer s.mu.RUnlock()

	names := make([]string, 0, len(s.entries))
	for name := range s.entries {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		info := s.entries[name]
		slog.Info("algorithm filing binding",
			"adapter", name,
			"gen_ai", MaskFilingNo(info.GenAIFilingNo),
			"deep_synth", MaskFilingNo(info.DeepSynthFilingNo),
			"valid_cn", info.IsValid(model.RegionCN),
			"source", s.source,
		)
	}
}

// MaskFilingNo returns a redacted filing number showing only the last four characters.
func MaskFilingNo(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "(empty)"
	}
	if len(raw) <= 4 {
		return "****"
	}
	return strings.Repeat("*", len(raw)-4) + raw[len(raw)-4:]
}
