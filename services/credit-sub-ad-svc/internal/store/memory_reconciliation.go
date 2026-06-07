package store

import (
	"context"
	"encoding/json"
	"sort"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *MemoryStore) ListBalances(_ context.Context) ([]model.Balance, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]model.Balance, 0, len(s.balances))
	for userID, row := range s.balances {
		out = append(out, *cloneBalance(userID, row))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].UserID < out[j].UserID })
	return out, nil
}

func (s *MemoryStore) ListHolds(_ context.Context) ([]model.Hold, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]model.Hold, 0, len(s.holds))
	for _, hold := range s.holds {
		out = append(out, *cloneHold(hold))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func (s *MemoryStore) ListIAPReceipts(_ context.Context) ([]model.IAPReceipt, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]model.IAPReceipt, 0, len(s.iapReceipts))
	for _, receipt := range s.iapReceipts {
		out = append(out, *cloneIAPReceipt(receipt))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].TransactionID < out[j].TransactionID })
	return out, nil
}

func (s *MemoryStore) ListLedgerByRefKind(_ context.Context, refKind string) ([]model.LedgerEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]model.LedgerEntry, 0)
	for _, entry := range s.ledger {
		if entry.RefKind == refKind {
			out = append(out, *cloneLedgerEntry(entry))
		}
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].CreatedAt.Equal(out[j].CreatedAt) {
			return out[i].ID < out[j].ID
		}
		return out[i].CreatedAt.Before(out[j].CreatedAt)
	})
	return out, nil
}

func (s *MemoryStore) LatestLedgerByUser(_ context.Context, userID string) (*model.LedgerEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var latest *model.LedgerEntry
	for _, entry := range s.ledger {
		if entry.UserID != userID {
			continue
		}
		if latest == nil || entry.CreatedAt.After(latest.CreatedAt) ||
			(entry.CreatedAt.Equal(latest.CreatedAt) && entry.ID > latest.ID) {
			latest = entry
		}
	}
	if latest == nil {
		return nil, ErrNotFound
	}
	return cloneLedgerEntry(latest), nil
}

func (s *MemoryStore) SaveReconciliationRun(_ context.Context, run model.ReconciliationRun) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	cloned := run
	if cloned.Report == nil {
		cloned.Report = map[string]any{}
	}
	if cloned.CreatedAt.IsZero() {
		cloned.CreatedAt = time.Now().UTC()
	}
	copyRun := cloned
	s.reconciliationRuns[run.ID] = &copyRun
	return nil
}

// ReconciliationRunCount returns stored audit rows (tests only).
func (s *MemoryStore) ReconciliationRunCount() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.reconciliationRuns)
}

// LastReconciliationRun returns the newest audit row (tests only).
func (s *MemoryStore) LastReconciliationRun() (*model.ReconciliationRun, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if len(s.reconciliationRuns) == 0 {
		return nil, ErrNotFound
	}
	var latest *model.ReconciliationRun
	for _, run := range s.reconciliationRuns {
		if latest == nil || run.CreatedAt.After(latest.CreatedAt) ||
			(run.CreatedAt.Equal(latest.CreatedAt) && run.ID > latest.ID) {
			latest = run
		}
	}
	out := *latest
	if out.Report != nil {
		raw, err := json.Marshal(out.Report)
		if err == nil {
			_ = json.Unmarshal(raw, &out.Report)
		}
	}
	return &out, nil
}
