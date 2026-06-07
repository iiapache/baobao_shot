package familyauth

import "context"

// Client verifies family membership for feed access.
type Client interface {
	CanAccessFamilyFeed(ctx context.Context, familyID string) error
}
