package store

import (
	"context"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// ReconciliationStore supports credit reconciliation queries and audit persistence.
type ReconciliationStore interface {
	ListAdRewards(ctx context.Context) ([]model.AdReward, error)
	ListBalances(ctx context.Context) ([]model.Balance, error)
	ListHolds(ctx context.Context) ([]model.Hold, error)
	ListIAPReceipts(ctx context.Context) ([]model.IAPReceipt, error)
	ListLedgerByRefKind(ctx context.Context, refKind string) ([]model.LedgerEntry, error)
	LatestLedgerByUser(ctx context.Context, userID string) (*model.LedgerEntry, error)
	SaveReconciliationRun(ctx context.Context, run model.ReconciliationRun) error
}
