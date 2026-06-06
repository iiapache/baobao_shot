package store

import (
	"fmt"
	"log/slog"
)

// RedisStore is a placeholder for Redis-backed config storage.
// Production: load Snapshot from Redis hash / pub-sub invalidation.
type RedisStore struct {
	url    string
	fallback *MemoryStore
}

// NewRedisStore creates a Redis store placeholder that falls back to memory seed data.
func NewRedisStore(url string) (*RedisStore, error) {
	if url == "" {
		return nil, fmt.Errorf("REDIS_URL is required when CONFIG_STORAGE=redis")
	}
	slog.Warn("redis config store not implemented; using in-memory seed as fallback",
		"redis_url", url)
	return &RedisStore{
		url:      url,
		fallback: NewMemoryStore(),
	}, nil
}

// GetSnapshot returns config from Redis or the in-memory fallback.
func (s *RedisStore) GetSnapshot() Snapshot {
	// TODO(T0.19+): HGETALL config:features / config:plays from Redis.
	return s.fallback.GetSnapshot()
}
