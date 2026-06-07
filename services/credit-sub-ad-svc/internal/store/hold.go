package store

import (
	"context"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// CreateHoldInput atomically debits balance and inserts a held reservation.
type CreateHoldInput struct {
	Hold            model.Hold
	ExpectedVersion int64
	NewBalance      int64
}

// CommitHoldInput marks a hold committed and appends a consume ledger row (no balance change).
type CommitHoldInput struct {
	HoldID      string
	LedgerEntry model.LedgerEntry
}

// ReleaseHoldInput marks a hold released, refunds balance, and appends a refund ledger row.
type ReleaseHoldInput struct {
	HoldID          string
	ExpectedVersion int64
	NewBalance      int64
	LedgerEntry     model.LedgerEntry
}

// CreditHoldStore persists saga reservations.
type CreditHoldStore interface {
	GetHoldByID(ctx context.Context, holdID string) (*model.Hold, error)
	GetHoldByAITaskID(ctx context.Context, aiTaskID string) (*model.Hold, error)
	CreateHoldWithDebit(ctx context.Context, in CreateHoldInput) error
	CommitHoldWithLedger(ctx context.Context, in CommitHoldInput) error
	ReleaseHoldWithRefund(ctx context.Context, in ReleaseHoldInput) error
}
