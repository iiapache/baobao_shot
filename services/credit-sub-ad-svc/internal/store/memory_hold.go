package store

import (
	"context"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *MemoryStore) GetHoldByID(_ context.Context, holdID string) (*model.Hold, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	hold, ok := s.holds[holdID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneHold(hold), nil
}

func (s *MemoryStore) GetHoldByAITaskID(_ context.Context, aiTaskID string) (*model.Hold, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	holdID, ok := s.holdsByTask[aiTaskID]
	if !ok {
		return nil, ErrNotFound
	}
	hold, ok := s.holds[holdID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneHold(hold), nil
}

func (s *MemoryStore) CreateHoldWithDebit(_ context.Context, in CreateHoldInput) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.holdsByTask[in.Hold.AITaskID]; exists {
		return ErrDuplicateHold
	}

	row, exists := s.balances[in.Hold.UserID]
	if !exists {
		if in.ExpectedVersion != 0 {
			return ErrVersionConflict
		}
		row = memoryBalance{version: 0}
	} else if row.version != in.ExpectedVersion {
		return ErrVersionConflict
	}

	row.balance = in.NewBalance
	row.version = in.ExpectedVersion + 1
	row.updatedAt = in.Hold.CreatedAt
	s.balances[in.Hold.UserID] = row

	hold := cloneHold(&in.Hold)
	s.holds[in.Hold.ID] = hold
	s.holdsByTask[in.Hold.AITaskID] = in.Hold.ID
	return nil
}

func (s *MemoryStore) CommitHoldWithLedger(_ context.Context, in CommitHoldInput) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := ledgerRefKey(in.LedgerEntry.RefKind, in.LedgerEntry.RefID)
	if _, exists := s.ledgerByRef[key]; exists {
		return ErrDuplicateRef
	}

	hold, ok := s.holds[in.HoldID]
	if !ok {
		return ErrNotFound
	}
	if hold.Status != model.HoldStatusHeld {
		return ErrHoldNotHeld
	}
	hold.Status = model.HoldStatusCommitted

	entry := cloneLedgerEntry(&in.LedgerEntry)
	s.ledger[in.LedgerEntry.ID] = entry
	s.ledgerByRef[key] = in.LedgerEntry.ID
	return nil
}

func (s *MemoryStore) ReleaseHoldWithRefund(_ context.Context, in ReleaseHoldInput) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := ledgerRefKey(in.LedgerEntry.RefKind, in.LedgerEntry.RefID)
	if _, exists := s.ledgerByRef[key]; exists {
		return ErrDuplicateRef
	}

	hold, ok := s.holds[in.HoldID]
	if !ok {
		return ErrNotFound
	}
	if hold.Status != model.HoldStatusHeld {
		return ErrHoldNotHeld
	}
	hold.Status = model.HoldStatusReleased

	row, exists := s.balances[in.LedgerEntry.UserID]
	if !exists {
		if in.ExpectedVersion != 0 {
			return ErrVersionConflict
		}
		row = memoryBalance{version: 0}
	} else if row.version != in.ExpectedVersion {
		return ErrVersionConflict
	}
	row.balance = in.NewBalance
	row.version = in.ExpectedVersion + 1
	row.updatedAt = in.LedgerEntry.CreatedAt
	s.balances[in.LedgerEntry.UserID] = row

	entry := cloneLedgerEntry(&in.LedgerEntry)
	s.ledger[in.LedgerEntry.ID] = entry
	s.ledgerByRef[key] = in.LedgerEntry.ID
	return nil
}

func cloneHold(hold *model.Hold) *model.Hold {
	if hold == nil {
		return nil
	}
	out := *hold
	return &out
}
