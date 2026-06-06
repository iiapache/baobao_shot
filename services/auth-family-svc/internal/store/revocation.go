package store

import (
	"context"
	"time"
)

// RevocationStore tracks revoked token JTIs until their original expiry.
type RevocationStore interface {
	Revoke(ctx context.Context, jti string, ttl time.Duration) error
	IsRevoked(ctx context.Context, jti string) (bool, error)
}
