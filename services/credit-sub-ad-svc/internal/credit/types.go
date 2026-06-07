package credit

import "github.com/baobao/credit-sub-ad-svc/internal/model"

type EntryType = model.EntryType

const (
	EntryGrant   = model.EntryGrant
	EntryCharge  = model.EntryCharge
	EntryConsume = model.EntryConsume
	EntryRefund  = model.EntryRefund
	EntryAdjust  = model.EntryAdjust
)

type Balance = model.Balance
type LedgerEntry = model.LedgerEntry

// ApplyRequest posts a single ledger movement.
type ApplyRequest struct {
	UserID  string
	Type    EntryType
	Amount  int64
	RefKind string
	RefID   string
}

// ApplyResult is the outcome of a ledger apply (including idempotent replays).
type ApplyResult struct {
	Entry     LedgerEntry
	Duplicate bool
}
