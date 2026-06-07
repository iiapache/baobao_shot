package store

import (
	"context"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// SignInStore reads and writes daily sign-in records.
type SignInStore interface {
	HasSignedIn(ctx context.Context, userID string, date time.Time) (bool, error)
	GetSignIn(ctx context.Context, userID string, date time.Time) (*model.SignInRecord, error)
	RecordSignIn(ctx context.Context, rec model.SignInRecord) (inserted bool, err error)
}
