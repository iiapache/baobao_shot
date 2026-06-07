package store

import (
	"context"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// SubscriptionStore persists subscription lifecycle records.
type SubscriptionStore interface {
	GetSubscriptionByOriginalTransactionID(ctx context.Context, originalTransactionID string) (*model.Subscription, error)
	GetLatestSubscriptionByUserID(ctx context.Context, userID string) (*model.Subscription, error)
	CreateSubscription(ctx context.Context, sub model.Subscription) error
	UpdateSubscription(ctx context.Context, sub model.Subscription) error
	ListSubscriptionsForExpiryScan(ctx context.Context, now time.Time) ([]model.Subscription, error)
}
