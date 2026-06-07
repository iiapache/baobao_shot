package cache

import (
	"context"
	"time"
)

// Store caches serialized feed list pages.
type Store interface {
	Get(ctx context.Context, key string) ([]byte, bool, error)
	Set(ctx context.Context, key string, value []byte, ttl time.Duration) error
}
