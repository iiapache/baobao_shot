package adreward

import (
	"sync"
	"time"
)

const defaultNonceTTL = 10 * time.Minute

// NonceGuard prevents replay on client-reported ad rewards.
type NonceGuard struct {
	mu      sync.Mutex
	seen    map[string]time.Time
	ttl     time.Duration
	now     func() time.Time
	skewMax time.Duration
}

// SetNow overrides the clock (tests only).
func (g *NonceGuard) SetNow(fn func() time.Time) {
	if g != nil && fn != nil {
		g.now = fn
	}
}

// NewNonceGuard creates an in-memory nonce cache.
func NewNonceGuard() *NonceGuard {
	return &NonceGuard{
		seen:    make(map[string]time.Time),
		ttl:     defaultNonceTTL,
		now:     time.Now,
		skewMax: 5 * time.Minute,
	}
}

// Validate checks nonce uniqueness and timestamp skew for client reports.
func (g *NonceGuard) Validate(nonce string, timestampMs int64) error {
	if g == nil {
		return nil
	}
	nonce = trim(nonce)
	if nonce == "" || timestampMs <= 0 {
		return ErrReplay
	}

	now := g.now().UTC()
	ts := time.UnixMilli(timestampMs).UTC()
	if ts.After(now.Add(g.skewMax)) || ts.Before(now.Add(-g.skewMax)) {
		return ErrReplay
	}

	g.mu.Lock()
	defer g.mu.Unlock()
	g.purgeLocked(now)
	if _, exists := g.seen[nonce]; exists {
		return ErrReplay
	}
	g.seen[nonce] = now.Add(g.ttl)
	return nil
}

func (g *NonceGuard) purgeLocked(now time.Time) {
	for nonce, expires := range g.seen {
		if !expires.After(now) {
			delete(g.seen, nonce)
		}
	}
}
