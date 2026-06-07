package cache

import (
	"log/slog"
)

// New selects Redis when configured, otherwise memory.
func New(redisURL string) Store {
	if redisURL == "" {
		return NewMemoryStore()
	}
	store, err := NewRedisStore(redisURL)
	if err != nil {
		slog.Warn("redis feed cache unavailable; using memory fallback", "error", err)
		return NewMemoryStore()
	}
	return store
}
