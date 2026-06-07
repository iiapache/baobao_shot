package model

import "time"

// EntryType is a ledger movement category (design-backend §4.1.3).
type EntryType string

const (
	EntryGrant   EntryType = "grant"
	EntryCharge  EntryType = "charge"
	EntryConsume EntryType = "consume"
	EntryRefund  EntryType = "refund"
	EntryAdjust  EntryType = "adjust"
)

// Balance is the current credit balance for a user.
type Balance struct {
	UserID    string
	Balance   int64
	Version   int64
	UpdatedAt time.Time
}

// LedgerEntry is an append-only ledger row.
type LedgerEntry struct {
	ID           string
	UserID       string
	Type         EntryType
	Amount       int64
	RefKind      string
	RefID        string
	BalanceAfter int64
	CreatedAt    time.Time
}
