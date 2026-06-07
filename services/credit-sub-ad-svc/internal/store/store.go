package store

import (
	"context"
)

// Store is the persistence boundary for credit-sub-ad-svc.
type Store interface {
	CreditLedgerStore
	CreditHoldStore
	IAPReceiptStore
	AdRewardStore
	SubscriptionStore
	SignInStore
	ReconciliationStore
	Ping(ctx context.Context) error
}
