package store

import (
	"context"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// ApplyLedgerInput carries one atomic ledger+balance write attempt.
type ApplyLedgerInput struct {
	Entry           model.LedgerEntry
	ExpectedVersion int64
	NewBalance      int64
}

// ListLedgerInput paginates ledger entries for one user (newest first).
type ListLedgerInput struct {
	UserID string
	Cursor string
	Limit  int
}

// ListLedgerResult is a page of ledger entries.
type ListLedgerResult struct {
	Items      []model.LedgerEntry
	NextCursor string
}

// CreditLedgerStore persists balances and append-only ledger entries.
type CreditLedgerStore interface {
	GetBalance(ctx context.Context, userID string) (*model.Balance, error)
	GetLedgerByRef(ctx context.Context, refKind, refID string) (*model.LedgerEntry, error)
	ListLedgerEntries(ctx context.Context, in ListLedgerInput) (ListLedgerResult, error)
	ApplyLedgerEntry(ctx context.Context, in ApplyLedgerInput) error
}
