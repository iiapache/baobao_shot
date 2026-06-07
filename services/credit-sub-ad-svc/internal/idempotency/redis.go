package idempotency

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	redisKeyPrefix = "credit:idem:"
	defaultTTL     = 7 * 24 * time.Hour
)

// RedisStore caches saga idempotency keys in Redis.
type RedisStore struct {
	client *redis.Client
	ttl    time.Duration
}

// NewRedisStore connects to Redis for saga idempotency.
func NewRedisStore(url string) (*RedisStore, error) {
	opts, err := redis.ParseURL(url)
	if err != nil {
		return nil, fmt.Errorf("parse redis url: %w", err)
	}
	client := redis.NewClient(opts)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("redis ping: %w", err)
	}
	return &RedisStore{client: client, ttl: defaultTTL}, nil
}

func (s *RedisStore) GetHoldID(ctx context.Context, refKind, refID string) (string, bool, error) {
	val, err := s.client.Get(ctx, redisKeyPrefix+holdKey(refKind, refID)).Result()
	if err == redis.Nil {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return val, val != "", nil
}

func (s *RedisStore) SaveHoldID(ctx context.Context, refKind, refID, holdID string) error {
	return s.client.Set(ctx, redisKeyPrefix+holdKey(refKind, refID), holdID, s.ttl).Err()
}

func (s *RedisStore) IsSettled(ctx context.Context, refKind, refID string) (bool, error) {
	n, err := s.client.Exists(ctx, redisKeyPrefix+settledKey(refKind, refID)).Result()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

func (s *RedisStore) MarkSettled(ctx context.Context, refKind, refID string) error {
	return s.client.Set(ctx, redisKeyPrefix+settledKey(refKind, refID), "1", s.ttl).Err()
}

// New selects Redis when configured, otherwise memory.
func New(redisURL string) Store {
	if redisURL == "" {
		return NewMemoryStore()
	}
	store, err := NewRedisStore(redisURL)
	if err != nil {
		slog.Warn("redis idempotency unavailable; using memory fallback", "error", err)
		return NewMemoryStore()
	}
	return store
}
