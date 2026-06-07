package credit

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/google/uuid"
)

const maxOptimisticRetries = 8

// Service applies append-only ledger movements with idempotency and optimistic locking.
type Service struct {
	store  store.CreditLedgerStore
	now    func() time.Time
	newID  func() string
}

// NewService creates a ledger service backed by the given store.
func NewService(st store.CreditLedgerStore) *Service {
	return &Service{
		store: st,
		now:   time.Now,
		newID: func() string { return "led_" + uuid.NewString()[:12] },
	}
}

// Grant credits a user (IAP, sign-in, ad reward, etc.).
func (s *Service) Grant(ctx context.Context, userID string, amount int64, refKind, refID string) (ApplyResult, error) {
	return s.Apply(ctx, ApplyRequest{
		UserID: userID, Type: EntryGrant, Amount: amount, RefKind: refKind, RefID: refID,
	})
}

// Charge debits credits (subscription renewal, etc.).
func (s *Service) Charge(ctx context.Context, userID string, amount int64, refKind, refID string) (ApplyResult, error) {
	return s.Apply(ctx, ApplyRequest{
		UserID: userID, Type: EntryCharge, Amount: amount, RefKind: refKind, RefID: refID,
	})
}

// Consume debits credits (AI task commit, etc.).
func (s *Service) Consume(ctx context.Context, userID string, amount int64, refKind, refID string) (ApplyResult, error) {
	return s.Apply(ctx, ApplyRequest{
		UserID: userID, Type: EntryConsume, Amount: amount, RefKind: refKind, RefID: refID,
	})
}

// Refund credits a user (AI task failure release, etc.).
func (s *Service) Refund(ctx context.Context, userID string, amount int64, refKind, refID string) (ApplyResult, error) {
	return s.Apply(ctx, ApplyRequest{
		UserID: userID, Type: EntryRefund, Amount: amount, RefKind: refKind, RefID: refID,
	})
}

// Clawback debits credits for IAP refund/revoke, allowing negative balance (design-backend §6.5).
func (s *Service) Clawback(ctx context.Context, userID string, amount int64, refKind, refID string) (ApplyResult, error) {
	req := ApplyRequest{
		UserID: userID, Type: EntryCharge, Amount: amount, RefKind: refKind, RefID: refID,
	}
	if err := validateApplyRequest(req); err != nil {
		return ApplyResult{}, err
	}
	if req.Amount <= 0 {
		return ApplyResult{}, ErrInvalidAmount
	}

	if existing, err := s.store.GetLedgerByRef(ctx, req.RefKind, req.RefID); err == nil {
		return ApplyResult{Entry: LedgerEntry(*existing), Duplicate: true}, nil
	} else if !errors.Is(err, store.ErrNotFound) {
		return ApplyResult{}, err
	}

	delta := -req.Amount
	var lastErr error
	for attempt := 0; attempt < maxOptimisticRetries; attempt++ {
		result, err := s.tryApplyAllowNegative(ctx, req, delta)
		if err == nil {
			return result, nil
		}
		if errors.Is(err, store.ErrVersionConflict) {
			lastErr = err
			continue
		}
		if errors.Is(err, store.ErrDuplicateRef) {
			existing, fetchErr := s.store.GetLedgerByRef(ctx, req.RefKind, req.RefID)
			if fetchErr != nil {
				return ApplyResult{}, fetchErr
			}
			return ApplyResult{Entry: LedgerEntry(*existing), Duplicate: true}, nil
		}
		return ApplyResult{}, err
	}
	return ApplyResult{}, lastErr
}

func (s *Service) tryApplyAllowNegative(ctx context.Context, req ApplyRequest, delta int64) (ApplyResult, error) {
	bal, err := s.store.GetBalance(ctx, req.UserID)
	version := int64(0)
	currentBalance := int64(0)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		return ApplyResult{}, err
	}
	if err == nil {
		version = bal.Version
		currentBalance = bal.Balance
	}

	newBalance := currentBalance + delta
	entry := LedgerEntry{
		ID:           s.newID(),
		UserID:       req.UserID,
		Type:         req.Type,
		Amount:       req.Amount,
		RefKind:      req.RefKind,
		RefID:        req.RefID,
		BalanceAfter: newBalance,
		CreatedAt:    s.now().UTC(),
	}

	if err := s.store.ApplyLedgerEntry(ctx, store.ApplyLedgerInput{
		Entry:           model.LedgerEntry(entry),
		ExpectedVersion: version,
		NewBalance:      newBalance,
	}); err != nil {
		return ApplyResult{}, err
	}
	return ApplyResult{Entry: entry, Duplicate: false}, nil
}

// Adjust applies a signed manual correction.
func (s *Service) Adjust(ctx context.Context, userID string, amount int64, refKind, refID string) (ApplyResult, error) {
	return s.Apply(ctx, ApplyRequest{
		UserID: userID, Type: EntryAdjust, Amount: amount, RefKind: refKind, RefID: refID,
	})
}

// GetBalance returns the current balance for a user (zero when no row exists).
func (s *Service) GetBalance(ctx context.Context, userID string) (Balance, error) {
	bal, err := s.store.GetBalance(ctx, userID)
	if errors.Is(err, store.ErrNotFound) {
		return Balance{UserID: userID, Balance: 0, Version: 0, UpdatedAt: s.now().UTC()}, nil
	}
	if err != nil {
		return Balance{}, err
	}
	return Balance(*bal), nil
}

// TransactionPage is a paginated ledger result.
type TransactionPage struct {
	Items      []LedgerEntry
	NextCursor string
}

// ListTransactions returns ledger entries for a user, newest first.
func (s *Service) ListTransactions(ctx context.Context, userID, cursor string, limit int) (TransactionPage, error) {
	page, err := s.store.ListLedgerEntries(ctx, store.ListLedgerInput{
		UserID: userID,
		Cursor: cursor,
		Limit:  limit,
	})
	if err != nil {
		return TransactionPage{}, err
	}
	items := make([]LedgerEntry, 0, len(page.Items))
	for _, entry := range page.Items {
		items = append(items, LedgerEntry(entry))
	}
	return TransactionPage{Items: items, NextCursor: page.NextCursor}, nil
}

// Apply posts one ledger movement with idempotency on ref_kind+ref_id.
func (s *Service) Apply(ctx context.Context, req ApplyRequest) (ApplyResult, error) {
	if err := validateApplyRequest(req); err != nil {
		return ApplyResult{}, err
	}

	if existing, err := s.store.GetLedgerByRef(ctx, req.RefKind, req.RefID); err == nil {
		return ApplyResult{Entry: LedgerEntry(*existing), Duplicate: true}, nil
	} else if !errors.Is(err, store.ErrNotFound) {
		return ApplyResult{}, err
	}

	delta, err := BalanceDelta(req.Type, req.Amount)
	if err != nil {
		return ApplyResult{}, err
	}

	var lastErr error
	for attempt := 0; attempt < maxOptimisticRetries; attempt++ {
		result, err := s.tryApply(ctx, req, delta)
		if err == nil {
			return result, nil
		}
		if errors.Is(err, store.ErrVersionConflict) {
			lastErr = err
			continue
		}
		if errors.Is(err, store.ErrDuplicateRef) {
			existing, fetchErr := s.store.GetLedgerByRef(ctx, req.RefKind, req.RefID)
			if fetchErr != nil {
				return ApplyResult{}, fetchErr
			}
			return ApplyResult{Entry: LedgerEntry(*existing), Duplicate: true}, nil
		}
		return ApplyResult{}, err
	}
	return ApplyResult{}, lastErr
}

func (s *Service) tryApply(ctx context.Context, req ApplyRequest, delta int64) (ApplyResult, error) {
	bal, err := s.store.GetBalance(ctx, req.UserID)
	version := int64(0)
	currentBalance := int64(0)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		return ApplyResult{}, err
	}
	if err == nil {
		version = bal.Version
		currentBalance = bal.Balance
	}

	newBalance := currentBalance + delta
	if newBalance < 0 {
		return ApplyResult{}, ErrInsufficientBalance
	}

	entry := LedgerEntry{
		ID:           s.newID(),
		UserID:       req.UserID,
		Type:         req.Type,
		Amount:       req.Amount,
		RefKind:      req.RefKind,
		RefID:        req.RefID,
		BalanceAfter: newBalance,
		CreatedAt:    s.now().UTC(),
	}

	if err := s.store.ApplyLedgerEntry(ctx, store.ApplyLedgerInput{
		Entry:           model.LedgerEntry(entry),
		ExpectedVersion: version,
		NewBalance:      newBalance,
	}); err != nil {
		return ApplyResult{}, err
	}
	return ApplyResult{Entry: entry, Duplicate: false}, nil
}

func validateApplyRequest(req ApplyRequest) error {
	if strings.TrimSpace(req.UserID) == "" ||
		strings.TrimSpace(req.RefKind) == "" ||
		strings.TrimSpace(req.RefID) == "" {
		return ErrInvalidRequest
	}
	switch req.Type {
	case EntryGrant, EntryCharge, EntryConsume, EntryRefund, EntryAdjust:
		return nil
	default:
		return ErrInvalidRequest
	}
}
