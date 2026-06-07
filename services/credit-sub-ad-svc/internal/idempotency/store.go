package idempotency

import (
	"context"
	"fmt"
)

const (
	kindHold    = "hold"
	kindSettled = "settled"
)

// Store caches saga idempotency outcomes (Redis with memory fallback for tests).
type Store interface {
	GetHoldID(ctx context.Context, refKind, refID string) (holdID string, ok bool, err error)
	SaveHoldID(ctx context.Context, refKind, refID, holdID string) error
	IsSettled(ctx context.Context, refKind, refID string) (bool, error)
	MarkSettled(ctx context.Context, refKind, refID string) error
}

func holdKey(refKind, refID string) string {
	return fmt.Sprintf("%s:%s:%s", kindHold, refKind, refID)
}

func settledKey(refKind, refID string) string {
	return fmt.Sprintf("%s:%s:%s", kindSettled, refKind, refID)
}
