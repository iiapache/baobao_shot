package store

import (
	"context"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

type memoryBalance struct {
	balance   int64
	version   int64
	updatedAt time.Time
}

func (s *MemoryStore) GetBalance(_ context.Context, userID string) (*model.Balance, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	row, ok := s.balances[userID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneBalance(userID, row), nil
}

func (s *MemoryStore) GetLedgerByRef(_ context.Context, refKind, refID string) (*model.LedgerEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	key := ledgerRefKey(refKind, refID)
	entryID, ok := s.ledgerByRef[key]
	if !ok {
		return nil, ErrNotFound
	}
	entry, ok := s.ledger[entryID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneLedgerEntry(entry), nil
}

func (s *MemoryStore) ApplyLedgerEntry(_ context.Context, in ApplyLedgerInput) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := ledgerRefKey(in.Entry.RefKind, in.Entry.RefID)
	if _, exists := s.ledgerByRef[key]; exists {
		return ErrDuplicateRef
	}

	row, exists := s.balances[in.Entry.UserID]
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
	row.updatedAt = in.Entry.CreatedAt
	s.balances[in.Entry.UserID] = row

	entry := cloneLedgerEntry(&in.Entry)
	s.ledger[in.Entry.ID] = entry
	s.ledgerByRef[key] = in.Entry.ID
	return nil
}

func ledgerRefKey(refKind, refID string) string {
	return refKind + "\x00" + refID
}

func cloneBalance(userID string, row memoryBalance) *model.Balance {
	return &model.Balance{
		UserID:    userID,
		Balance:   row.balance,
		Version:   row.version,
		UpdatedAt: row.updatedAt,
	}
}

func cloneLedgerEntry(entry *model.LedgerEntry) *model.LedgerEntry {
	if entry == nil {
		return nil
	}
	out := *entry
	return &out
}
