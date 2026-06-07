package credit

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func newTestService() *Service {
	svc := NewService(store.NewMemoryStore())
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC) }
	svc.newID = func() string { return "led_test" }
	return svc
}

func TestGrantIncreasesBalance(t *testing.T) {
	svc := newTestService()
	ctx := context.Background()

	result, err := svc.Grant(ctx, "usr_1", 100, "iap", "tx_1")
	if err != nil {
		t.Fatalf("Grant() error = %v", err)
	}
	if result.Duplicate {
		t.Fatal("expected first grant not duplicate")
	}
	if result.Entry.BalanceAfter != 100 {
		t.Fatalf("balanceAfter = %d, want 100", result.Entry.BalanceAfter)
	}

	bal, err := svc.GetBalance(ctx, "usr_1")
	if err != nil {
		t.Fatalf("GetBalance() error = %v", err)
	}
	if bal.Balance != 100 || bal.Version != 1 {
		t.Fatalf("balance = %+v, want balance=100 version=1", bal)
	}
}

func TestConsumeDecreasesBalance(t *testing.T) {
	svc := newTestService()
	ctx := context.Background()

	if _, err := svc.Grant(ctx, "usr_2", 50, "sign_in", "2026-06-06"); err != nil {
		t.Fatal(err)
	}
	result, err := svc.Consume(ctx, "usr_2", 8, "ai_task", "tsk_1")
	if err != nil {
		t.Fatalf("Consume() error = %v", err)
	}
	if result.Entry.BalanceAfter != 42 {
		t.Fatalf("balanceAfter = %d, want 42", result.Entry.BalanceAfter)
	}
}

func TestInsufficientBalance(t *testing.T) {
	svc := newTestService()
	ctx := context.Background()

	_, err := svc.Consume(ctx, "usr_3", 1, "ai_task", "tsk_low")
	if !errors.Is(err, ErrInsufficientBalance) {
		t.Fatalf("Consume() error = %v, want ErrInsufficientBalance", err)
	}
}

func TestIdempotentRefReturnsOriginalResult(t *testing.T) {
	svc := newTestService()
	ctx := context.Background()

	first, err := svc.Grant(ctx, "usr_4", 20, "ad_reward", "sig_1")
	if err != nil {
		t.Fatal(err)
	}
	second, err := svc.Grant(ctx, "usr_4", 999, "ad_reward", "sig_1")
	if err != nil {
		t.Fatalf("duplicate Grant() error = %v", err)
	}
	if !second.Duplicate {
		t.Fatal("expected duplicate=true")
	}
	if second.Entry.ID != first.Entry.ID {
		t.Fatalf("ledger id mismatch: %s vs %s", second.Entry.ID, first.Entry.ID)
	}
	if second.Entry.Amount != 20 {
		t.Fatalf("duplicate amount = %d, want 20", second.Entry.Amount)
	}

	bal, err := svc.GetBalance(ctx, "usr_4")
	if err != nil {
		t.Fatal(err)
	}
	if bal.Balance != 20 {
		t.Fatalf("balance = %d, want 20 (no double grant)", bal.Balance)
	}
}

func TestConcurrentGrantsBalanceAccurate(t *testing.T) {
	svc := NewService(store.NewMemoryStore())
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC) }
	ctx := context.Background()
	userID := "usr_concurrent"

	const workers = 50
	var wg sync.WaitGroup
	wg.Add(workers)
	errCh := make(chan error, workers)

	for i := 0; i < workers; i++ {
		i := i
		go func() {
			defer wg.Done()
			_, err := svc.Grant(ctx, userID, 1, "load_test", fmt.Sprintf("grant_%d", i))
			if err != nil {
				errCh <- err
			}
		}()
	}
	wg.Wait()
	close(errCh)
	for err := range errCh {
		t.Fatalf("concurrent Grant() error = %v", err)
	}

	bal, err := svc.GetBalance(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if bal.Balance != workers {
		t.Fatalf("balance = %d, want %d", bal.Balance, workers)
	}
	if bal.Version != workers {
		t.Fatalf("version = %d, want %d", bal.Version, workers)
	}
}

func TestConcurrentMixedOperationsBalanceAccurate(t *testing.T) {
	svc := NewService(store.NewMemoryStore())
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC) }
	ctx := context.Background()
	userID := "usr_mixed"

	if _, err := svc.Grant(ctx, userID, 1000, "bootstrap", "init"); err != nil {
		t.Fatal(err)
	}

	const workers = 50
	var wg sync.WaitGroup
	wg.Add(workers)
	errCh := make(chan error, workers)

	for i := 0; i < workers; i++ {
		i := i
		go func() {
			defer wg.Done()
			refID := fmt.Sprintf("op_%d", i)
			var err error
			switch i % 5 {
			case 0:
				_, err = svc.Grant(ctx, userID, 2, "grant", refID)
			case 1:
				_, err = svc.Charge(ctx, userID, 1, "charge", refID)
			case 2:
				_, err = svc.Consume(ctx, userID, 1, "consume", refID)
			case 3:
				_, err = svc.Refund(ctx, userID, 1, "refund", refID)
			case 4:
				_, err = svc.Adjust(ctx, userID, 1, "adjust", refID)
			}
			if err != nil {
				errCh <- err
			}
		}()
	}
	wg.Wait()
	close(errCh)
	for err := range errCh {
		t.Fatalf("concurrent op error = %v", err)
	}

	// 1000 + 10*2 (grant) - 10*1 (charge) - 10*1 (consume) + 10*1 (refund) + 10*1 (adjust) = 1020
	bal, err := svc.GetBalance(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if bal.Balance != 1020 {
		t.Fatalf("balance = %d, want 1020", bal.Balance)
	}
}

func TestAllEntryTypes(t *testing.T) {
	svc := newTestService()
	ctx := context.Background()
	userID := "usr_types"

	cases := []struct {
		name   string
		apply  func() (ApplyResult, error)
		expect int64
	}{
		{
			name: "grant",
			apply: func() (ApplyResult, error) {
				return svc.Grant(ctx, userID, 100, "grant", "g1")
			},
			expect: 100,
		},
		{
			name: "charge",
			apply: func() (ApplyResult, error) {
				return svc.Charge(ctx, userID, 10, "charge", "c1")
			},
			expect: 90,
		},
		{
			name: "consume",
			apply: func() (ApplyResult, error) {
				return svc.Consume(ctx, userID, 5, "consume", "co1")
			},
			expect: 85,
		},
		{
			name: "refund",
			apply: func() (ApplyResult, error) {
				return svc.Refund(ctx, userID, 5, "refund", "r1")
			},
			expect: 90,
		},
		{
			name: "adjust",
			apply: func() (ApplyResult, error) {
				return svc.Adjust(ctx, userID, -10, "adjust", "a1")
			},
			expect: 80,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			result, err := tc.apply()
			if err != nil {
				t.Fatalf("%s error = %v", tc.name, err)
			}
			if result.Entry.BalanceAfter != tc.expect {
				t.Fatalf("%s balanceAfter = %d, want %d", tc.name, result.Entry.BalanceAfter, tc.expect)
			}
		})
	}
}
