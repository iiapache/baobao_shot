package credit

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/idempotency"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/google/uuid"
)

const (
	RefKindAITaskHold    = "ai_task_hold"
	RefKindAITaskCommit  = "ai_task_commit"
	RefKindAITaskRelease = "ai_task_release"
)

// HoldInput reserves credits for an AI task saga step.
type HoldInput struct {
	UserID   string
	AITaskID string
	Amount   int64
	RefKind  string
	RefID    string
}

// HoldResult is the outcome of a hold request.
type HoldResult struct {
	HoldID    string
	Duplicate bool
}

// SettleInput commits or releases a prior hold.
type SettleInput struct {
	HoldID   string
	AITaskID string
	RefKind  string
	RefID    string
}

// SettleResult is the outcome of commit/release.
type SettleResult struct {
	Duplicate bool
}

// SagaService implements hold/commit/release (design-backend §6.1).
type SagaService struct {
	store store.CreditHoldStore
	ledger store.CreditLedgerStore
	idem  idempotency.Store
	now   func() time.Time
	newHoldID func() string
	newLedgerID func() string
}

// NewSagaService creates a saga orchestrator backed by the given stores.
func NewSagaService(st store.Store, idem idempotency.Store) *SagaService {
	return &SagaService{
		store: st,
		ledger: st,
		idem:  idem,
		now:   time.Now,
		newHoldID: func() string { return "hld_" + uuid.NewString() },
		newLedgerID: func() string { return "led_" + uuid.NewString()[:12] },
	}
}

// Hold reserves credits and debits balance atomically.
func (s *SagaService) Hold(ctx context.Context, in HoldInput) (HoldResult, error) {
	in = normalizeHold(in)
	if err := validateHold(in); err != nil {
		return HoldResult{}, err
	}

	if holdID, ok, err := s.idem.GetHoldID(ctx, in.RefKind, in.RefID); err != nil {
		return HoldResult{}, err
	} else if ok {
		return HoldResult{HoldID: holdID, Duplicate: true}, nil
	}

	if existing, err := s.store.GetHoldByAITaskID(ctx, in.AITaskID); err == nil {
		_ = s.idem.SaveHoldID(ctx, in.RefKind, in.RefID, existing.ID)
		return HoldResult{HoldID: existing.ID, Duplicate: true}, nil
	} else if !errors.Is(err, store.ErrNotFound) {
		return HoldResult{}, err
	}

	bal, err := s.ledger.GetBalance(ctx, in.UserID)
	version := int64(0)
	currentBalance := int64(0)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		return HoldResult{}, err
	}
	if err == nil {
		version = bal.Version
		currentBalance = bal.Balance
	}

	newBalance := currentBalance - in.Amount
	if newBalance < 0 {
		return HoldResult{}, ErrInsufficientBalance
	}

	holdID := s.newHoldID()
	hold := model.Hold{
		ID:        holdID,
		UserID:    in.UserID,
		AITaskID:  in.AITaskID,
		Amount:    in.Amount,
		Status:    model.HoldStatusHeld,
		CreatedAt: s.now().UTC(),
	}
	err = s.store.CreateHoldWithDebit(ctx, store.CreateHoldInput{
		Hold:            hold,
		ExpectedVersion: version,
		NewBalance:      newBalance,
	})
	if errors.Is(err, store.ErrDuplicateHold) {
		existing, fetchErr := s.store.GetHoldByAITaskID(ctx, in.AITaskID)
		if fetchErr != nil {
			return HoldResult{}, fetchErr
		}
		_ = s.idem.SaveHoldID(ctx, in.RefKind, in.RefID, existing.ID)
		return HoldResult{HoldID: existing.ID, Duplicate: true}, nil
	}
	if err != nil {
		return HoldResult{}, err
	}

	_ = s.idem.SaveHoldID(ctx, in.RefKind, in.RefID, holdID)
	return HoldResult{HoldID: holdID}, nil
}

// Commit finalizes a hold and records consume ledger without changing balance.
func (s *SagaService) Commit(ctx context.Context, in SettleInput) (SettleResult, error) {
	in = normalizeCommit(in)
	if err := validateSettle(in); err != nil {
		return SettleResult{}, err
	}

	if settled, err := s.idem.IsSettled(ctx, in.RefKind, in.RefID); err != nil {
		return SettleResult{}, err
	} else if settled {
		return SettleResult{Duplicate: true}, nil
	}

	if existing, err := s.ledger.GetLedgerByRef(ctx, in.RefKind, in.RefID); err == nil {
		_ = s.idem.MarkSettled(ctx, in.RefKind, in.RefID)
		_ = existing
		return SettleResult{Duplicate: true}, nil
	} else if !errors.Is(err, store.ErrNotFound) {
		return SettleResult{}, err
	}

	hold, err := s.store.GetHoldByID(ctx, in.HoldID)
	if errors.Is(err, store.ErrNotFound) {
		return SettleResult{}, ErrHoldNotFound
	}
	if err != nil {
		return SettleResult{}, err
	}
	if hold.Status != model.HoldStatusHeld {
		return SettleResult{}, ErrHoldSettled
	}

	bal, err := s.ledger.GetBalance(ctx, hold.UserID)
	if errors.Is(err, store.ErrNotFound) {
		return SettleResult{}, ErrHoldNotFound
	}
	if err != nil {
		return SettleResult{}, err
	}

	entry := model.LedgerEntry{
		ID:           s.newLedgerID(),
		UserID:       hold.UserID,
		Type:         EntryConsume,
		Amount:       hold.Amount,
		RefKind:      in.RefKind,
		RefID:        in.RefID,
		BalanceAfter: bal.Balance,
		CreatedAt:    s.now().UTC(),
	}
	err = s.store.CommitHoldWithLedger(ctx, store.CommitHoldInput{
		HoldID:      in.HoldID,
		LedgerEntry: entry,
	})
	if errors.Is(err, store.ErrDuplicateRef) {
		_ = s.idem.MarkSettled(ctx, in.RefKind, in.RefID)
		return SettleResult{Duplicate: true}, nil
	}
	if errors.Is(err, store.ErrHoldNotHeld) {
		return SettleResult{}, ErrHoldSettled
	}
	if err != nil {
		return SettleResult{}, err
	}

	_ = s.idem.MarkSettled(ctx, in.RefKind, in.RefID)
	return SettleResult{}, nil
}

// Release refunds a held amount back to balance.
func (s *SagaService) Release(ctx context.Context, in SettleInput) (SettleResult, error) {
	in = normalizeRelease(in)
	if err := validateSettle(in); err != nil {
		return SettleResult{}, err
	}

	if settled, err := s.idem.IsSettled(ctx, in.RefKind, in.RefID); err != nil {
		return SettleResult{}, err
	} else if settled {
		return SettleResult{Duplicate: true}, nil
	}

	if existing, err := s.ledger.GetLedgerByRef(ctx, in.RefKind, in.RefID); err == nil {
		_ = s.idem.MarkSettled(ctx, in.RefKind, in.RefID)
		_ = existing
		return SettleResult{Duplicate: true}, nil
	} else if !errors.Is(err, store.ErrNotFound) {
		return SettleResult{}, err
	}

	hold, err := s.store.GetHoldByID(ctx, in.HoldID)
	if errors.Is(err, store.ErrNotFound) {
		return SettleResult{}, ErrHoldNotFound
	}
	if err != nil {
		return SettleResult{}, err
	}
	if hold.Status != model.HoldStatusHeld {
		return SettleResult{}, ErrHoldSettled
	}

	bal, err := s.ledger.GetBalance(ctx, hold.UserID)
	version := int64(0)
	currentBalance := int64(0)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		return SettleResult{}, err
	}
	if err == nil {
		version = bal.Version
		currentBalance = bal.Balance
	}

	newBalance := currentBalance + hold.Amount
	entry := model.LedgerEntry{
		ID:           s.newLedgerID(),
		UserID:       hold.UserID,
		Type:         EntryRefund,
		Amount:       hold.Amount,
		RefKind:      in.RefKind,
		RefID:        in.RefID,
		BalanceAfter: newBalance,
		CreatedAt:    s.now().UTC(),
	}
	err = s.store.ReleaseHoldWithRefund(ctx, store.ReleaseHoldInput{
		HoldID:          in.HoldID,
		ExpectedVersion: version,
		NewBalance:      newBalance,
		LedgerEntry:     entry,
	})
	if errors.Is(err, store.ErrDuplicateRef) {
		_ = s.idem.MarkSettled(ctx, in.RefKind, in.RefID)
		return SettleResult{Duplicate: true}, nil
	}
	if errors.Is(err, store.ErrHoldNotHeld) {
		return SettleResult{}, ErrHoldSettled
	}
	if err != nil {
		return SettleResult{}, err
	}

	_ = s.idem.MarkSettled(ctx, in.RefKind, in.RefID)
	return SettleResult{}, nil
}

func normalizeHold(in HoldInput) HoldInput {
	if in.RefKind == "" {
		in.RefKind = RefKindAITaskHold
	}
	if in.RefID == "" {
		in.RefID = in.AITaskID
	}
	return in
}

func normalizeCommit(in SettleInput) SettleInput {
	if in.RefKind == "" {
		in.RefKind = RefKindAITaskCommit
	}
	if in.RefID == "" {
		in.RefID = in.AITaskID
	}
	return in
}

func normalizeRelease(in SettleInput) SettleInput {
	if in.RefKind == "" {
		in.RefKind = RefKindAITaskRelease
	}
	if in.RefID == "" {
		in.RefID = in.AITaskID
	}
	return in
}

func validateHold(in HoldInput) error {
	if strings.TrimSpace(in.UserID) == "" ||
		strings.TrimSpace(in.AITaskID) == "" ||
		in.Amount <= 0 {
		return ErrInvalidRequest
	}
	return nil
}

func validateSettle(in SettleInput) error {
	if strings.TrimSpace(in.HoldID) == "" {
		return ErrInvalidRequest
	}
	return nil
}
