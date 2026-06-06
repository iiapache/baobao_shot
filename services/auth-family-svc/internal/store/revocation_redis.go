package store

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

const revokedKeyPrefix = "token:revoked:"

// RedisRevocationStore persists revoked JTIs in Redis with TTL.
type RedisRevocationStore struct {
	client *redis.Client
}

// NewRedisRevocationStore connects to Redis for token revocation.
func NewRedisRevocationStore(url string) (*RedisRevocationStore, error) {
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
	return &RedisRevocationStore{client: client}, nil
}

// Revoke stores the JTI until ttl expires.
func (s *RedisRevocationStore) Revoke(ctx context.Context, jti string, ttl time.Duration) error {
	if jti == "" {
		return nil
	}
	if ttl <= 0 {
		ttl = time.Second
	}
	return s.client.Set(ctx, revokedKeyPrefix+jti, "1", ttl).Err()
}

// IsRevoked checks whether the JTI is blacklisted.
func (s *RedisRevocationStore) IsRevoked(ctx context.Context, jti string) (bool, error) {
	if jti == "" {
		return false, nil
	}
	n, err := s.client.Exists(ctx, revokedKeyPrefix+jti).Result()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// NewRevocationStore selects Redis when configured, otherwise memory.
func NewRevocationStore(redisURL string) RevocationStore {
	if redisURL == "" {
		return NewMemoryRevocationStore()
	}
	store, err := NewRedisRevocationStore(redisURL)
	if err != nil {
		slog.Warn("redis revocation unavailable; using memory fallback", "error", err)
		return NewMemoryRevocationStore()
	}
	return store
}
