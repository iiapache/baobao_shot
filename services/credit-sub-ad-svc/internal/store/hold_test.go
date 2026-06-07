package store_test

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func TestMemoryHoldLifecycle(t *testing.T) {
	st := store.NewMemoryStore()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)

	hold := model.Hold{
		ID: "hld_1", UserID: "usr_1", AITaskID: "tsk_1", Amount: 8,
		Status: model.HoldStatusHeld, CreatedAt: now,
	}
	if err := st.CreateHoldWithDebit(ctx, store.CreateHoldInput{
		Hold: hold, ExpectedVersion: 0, NewBalance: 92,
	}); err != nil {
		t.Fatalf("CreateHoldWithDebit() error = %v", err)
	}

	got, err := st.GetHoldByAITaskID(ctx, "tsk_1")
	if err != nil || got.ID != "hld_1" {
		t.Fatalf("GetHoldByAITaskID() = %+v err=%v", got, err)
	}

	entry := model.LedgerEntry{
		ID: "led_1", UserID: "usr_1", Type: model.EntryConsume, Amount: 8,
		RefKind: "ai_task_commit", RefID: "tsk_1", BalanceAfter: 92, CreatedAt: now,
	}
	if err := st.CommitHoldWithLedger(ctx, store.CommitHoldInput{HoldID: "hld_1", LedgerEntry: entry}); err != nil {
		t.Fatalf("CommitHoldWithLedger() error = %v", err)
	}

	got, err = st.GetHoldByID(ctx, "hld_1")
	if err != nil || got.Status != model.HoldStatusCommitted {
		t.Fatalf("hold after commit = %+v err=%v", got, err)
	}
}
