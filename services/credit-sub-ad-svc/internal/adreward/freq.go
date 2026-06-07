package adreward

import (
	"sync"
	"time"
)

// FreqGuard enforces per-user and per-idfv frequency windows and daily caps.
type FreqGuard struct {
	mu              sync.Mutex
	lastByUser      map[string]time.Time
	lastByIDFV      map[string]time.Time
	dailyByUser     map[string]int
	dailyByIDFV     map[string]int
	dailyKey        func(time.Time) string
	minInterval     time.Duration
	dailyLimit      int
}

// NewFreqGuard creates an in-memory frequency guard.
func NewFreqGuard(minInterval time.Duration, dailyLimit int) *FreqGuard {
	if dailyLimit <= 0 {
		dailyLimit = DefaultDailyLimit
	}
	return &FreqGuard{
		lastByUser:  make(map[string]time.Time),
		lastByIDFV:  make(map[string]time.Time),
		dailyByUser: make(map[string]int),
		dailyByIDFV: make(map[string]int),
		dailyKey:    func(t time.Time) string { return t.UTC().Format("2006-01-02") },
		minInterval: minInterval,
		dailyLimit:  dailyLimit,
	}
}

// Check evaluates frequency and daily limits before a new reward.
func (g *FreqGuard) Check(now time.Time, userID, idfv string, userDayCount int) error {
	if g == nil {
		return nil
	}
	g.mu.Lock()
	defer g.mu.Unlock()

	day := g.dailyKey(now)
	if userDayCount >= g.dailyLimit {
		return ErrDailyLimit
	}

	if g.minInterval > 0 {
		if last, ok := g.lastByUser[userID]; ok && now.Sub(last) < g.minInterval {
			return ErrFrequencyLimit
		}
	}

	if idfv != "" {
		idfvDayKey := day + ":" + idfv
		if g.dailyByIDFV[idfvDayKey] >= g.dailyLimit {
			return ErrDailyLimit
		}
		if g.minInterval > 0 {
			if last, ok := g.lastByIDFV[idfv]; ok && now.Sub(last) < g.minInterval {
				return ErrFrequencyLimit
			}
		}
	}
	return nil
}

// Record marks a successful reward for frequency tracking.
func (g *FreqGuard) Record(now time.Time, userID, idfv string) {
	if g == nil {
		return
	}
	g.mu.Lock()
	defer g.mu.Unlock()

	day := g.dailyKey(now)
	g.lastByUser[userID] = now
	g.dailyByUser[day+":"+userID]++

	if idfv != "" {
		g.lastByIDFV[idfv] = now
		g.dailyByIDFV[day+":"+idfv]++
	}
}
