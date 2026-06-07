package familyauth

import (
	"context"

	"github.com/baobao/feed-svc/internal/middleware"
)

// Stub checks JWT family claims when present; skips in dev when claims are absent.
type Stub struct{}

// NewStub returns the default family auth client.
func NewStub() *Stub {
	return &Stub{}
}

// CanAccessFamilyFeed allows any guest+ member of the family.
func (s *Stub) CanAccessFamilyFeed(ctx context.Context, familyID string) error {
	families, ok := middleware.FamiliesFromContext(ctx)
	if !ok || len(families) == 0 {
		return nil
	}
	for _, f := range families {
		if f.FamilyID == familyID {
			return nil
		}
	}
	return ErrForbidden
}
