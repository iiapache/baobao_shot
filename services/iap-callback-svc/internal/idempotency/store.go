package idempotency

import "context"

// Store deduplicates Apple notification UUIDs.
type Store interface {
	TryClaim(ctx context.Context, notificationUUID string) (claimed bool, err error)
}
