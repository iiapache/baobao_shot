package credit

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/idempotency"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func newTestSaga() (*SagaService, store.Store) {
	st := store.NewMemoryStore()
	svc := NewSagaService(st, idempotency.NewMemoryStore())
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC) }
	svc.newHoldID = func() string { return "hld_test" }
	svc.newLedgerID = func() string { return "led_test" }
	return svc, st
}

func grantBalance(t *testing.T, st store.Store, userID string, amount int64) {
	t.Helper()
	ledger := NewService(st)
	if _, err := ledger.Grant(context.Background(), userID, amount, "bootstrap", userID); err != nil {
		t.Fatalf("Grant() error = %v", err)
	}
}

func TestSagaService_HoldIdempotent(t *testing.T) {
	svc, st := newTestSaga()
	grantBalance(t, st, "usr_1", 100)
	ctx := context.Background()

	req := HoldInput{UserID: "usr_1", AITaskID: "tsk_1", Amount: 8}
	first, err := svc.Hold(ctx, req)
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}
	second, err := svc.Hold(ctx, req)
	if err != nil {
		t.Fatalf("Hold() duplicate error = %v", err)
	}
	if first.HoldID != second.HoldID || !second.Duplicate {
		t.Fatalf("duplicate hold = %+v, want holdId=%s duplicate=true", second, first.HoldID)
	}
}

func TestSagaService_CommitThenReleaseBlocked(t *testing.T) {
	svc, st := newTestSaga()
	grantBalance(t, st, "usr_1", 100)
	ctx := context.Background()

	hold, err := svc.Hold(ctx, HoldInput{UserID: "usr_1", AITaskID: "tsk_ok", Amount: 8})
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}
	if _, err := svc.Commit(ctx, SettleInput{HoldID: hold.HoldID, AITaskID: "tsk_ok"}); err != nil {
		t.Fatalf("Commit() error = %v", err)
	}
	if _, err := svc.Release(ctx, SettleInput{HoldID: hold.HoldID, AITaskID: "tsk_ok"}); !errors.Is(err, ErrHoldSettled) {
		t.Fatalf("Release() after commit error = %v, want ErrHoldSettled", err)
	}
}

func TestSagaService_FailureRelease(t *testing.T) {
	svc, st := newTestSaga()
	grantBalance(t, st, "usr_1", 100)
	ctx := context.Background()

	hold, err := svc.Hold(ctx, HoldInput{UserID: "usr_1", AITaskID: "tsk_fail", Amount: 8})
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}

	resp, err := svc.Release(ctx, SettleInput{HoldID: hold.HoldID, AITaskID: "tsk_fail"})
	if err != nil {
		t.Fatalf("Release() error = %v", err)
	}
	if resp.Duplicate {
		t.Fatal("first release should not be duplicate")
	}

	dup, err := svc.Release(ctx, SettleInput{HoldID: hold.HoldID, AITaskID: "tsk_fail"})
	if err != nil {
		t.Fatalf("Release() duplicate error = %v", err)
	}
	if !dup.Duplicate {
		t.Fatal("second release should be duplicate")
	}
}

func TestSagaService_HoldInsufficientBalance(t *testing.T) {
	svc, _ := newTestSaga()
	ctx := context.Background()

	_, err := svc.Hold(ctx, HoldInput{UserID: "usr_low", AITaskID: "tsk_low", Amount: 8})
	if !errors.Is(err, ErrInsufficientBalance) {
		t.Fatalf("Hold() error = %v, want ErrInsufficientBalance", err)
	}
}

func TestSagaService_CommitIdempotent(t *testing.T) {
	svc, st := newTestSaga()
	grantBalance(t, st, "usr_1", 100)
	ctx := context.Background()

	hold, err := svc.Hold(ctx, HoldInput{UserID: "usr_1", AITaskID: "tsk_commit", Amount: 8})
	if err != nil {
		t.Fatal(err)
	}
	settle := SettleInput{HoldID: hold.HoldID, AITaskID: "tsk_commit"}
	if _, err := svc.Commit(ctx, settle); err != nil {
		t.Fatal(err)
	}
	dup, err := svc.Commit(ctx, settle)
	if err != nil {
		t.Fatal(err)
	}
	if !dup.Duplicate {
		t.Fatal("second commit should be duplicate")
	}
}

func TestSagaService_HoldDebitsBalanceReleaseRefunds(t *testing.T) {
	svc, st := newTestSaga()
	grantBalance(t, st, "usr_1", 100)
	ctx := context.Background()
	ledger := NewService(st)

	hold, err := svc.Hold(ctx, HoldInput{UserID: "usr_1", AITaskID: "tsk_bal", Amount: 8})
	if err != nil {
		t.Fatal(err)
	}
	bal, err := ledger.GetBalance(ctx, "usr_1")
	if err != nil || bal.Balance != 92 {
		t.Fatalf("after hold balance = %+v, want 92", bal)
	}

	if _, err := svc.Release(ctx, SettleInput{HoldID: hold.HoldID, AITaskID: "tsk_bal"}); err != nil {
		t.Fatal(err)
	}
	bal, err = ledger.GetBalance(ctx, "usr_1")
	if err != nil || bal.Balance != 100 {
		t.Fatalf("after release balance = %+v, want 100", bal)
	}
}
