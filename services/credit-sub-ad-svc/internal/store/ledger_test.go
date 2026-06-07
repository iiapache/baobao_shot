package store

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
	_ "github.com/lib/pq"
)

func TestMemoryLedgerApplyAndIdempotency(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)

	entry := model.LedgerEntry{
		ID: "led_1", UserID: "usr_mem", Type: model.EntryGrant, Amount: 10,
		RefKind: "test", RefID: "ref_1", BalanceAfter: 10, CreatedAt: now,
	}
	if err := st.ApplyLedgerEntry(ctx, ApplyLedgerInput{
		Entry: entry, ExpectedVersion: 0, NewBalance: 10,
	}); err != nil {
		t.Fatalf("first apply: %v", err)
	}
	if err := st.ApplyLedgerEntry(ctx, ApplyLedgerInput{
		Entry: entry, ExpectedVersion: 0, NewBalance: 10,
	}); err != ErrDuplicateRef {
		t.Fatalf("second apply error = %v, want ErrDuplicateRef", err)
	}

	got, err := st.GetLedgerByRef(ctx, "test", "ref_1")
	if err != nil {
		t.Fatal(err)
	}
	if got.ID != "led_1" {
		t.Fatalf("ledger id = %s", got.ID)
	}

	bal, err := st.GetBalance(ctx, "usr_mem")
	if err != nil {
		t.Fatal(err)
	}
	if bal.Balance != 10 || bal.Version != 1 {
		t.Fatalf("balance = %+v", bal)
	}
}

func TestMemoryConcurrentApply(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	userID := "usr_mem_conc"

	const workers = 50
	var wg sync.WaitGroup
	wg.Add(workers)
	errCh := make(chan error, workers)

	for i := 0; i < workers; i++ {
		i := i
		go func() {
			defer wg.Done()
			entry := model.LedgerEntry{
				ID:           fmt.Sprintf("led_%d", i),
				UserID:       userID,
				Type:         model.EntryGrant,
				Amount:       1,
				RefKind:      "conc",
				RefID:        fmt.Sprintf("ref_%d", i),
				BalanceAfter: 0, // store layer does not validate; service does
				CreatedAt:    now,
			}
			for attempt := 0; attempt < 8; attempt++ {
				bal, err := st.GetBalance(ctx, userID)
				version := int64(0)
				current := int64(0)
				if err == nil {
					version = bal.Version
					current = bal.Balance
				} else if err != ErrNotFound {
					errCh <- err
					return
				}
				entry.BalanceAfter = current + 1
				err = st.ApplyLedgerEntry(ctx, ApplyLedgerInput{
					Entry: entry, ExpectedVersion: version, NewBalance: entry.BalanceAfter,
				})
				if err == nil {
					return
				}
				if err != ErrVersionConflict {
					errCh <- err
					return
				}
			}
			errCh <- ErrVersionConflict
		}()
	}
	wg.Wait()
	close(errCh)
	for err := range errCh {
		t.Fatalf("concurrent apply error = %v", err)
	}

	bal, err := st.GetBalance(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if bal.Balance != workers {
		t.Fatalf("balance = %d, want %d", bal.Balance, workers)
	}
}

func TestPostgresLedgerConcurrentApply(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping postgres ledger test")
	}

	ctx := context.Background()
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("open postgres: %v", err)
	}
	defer db.Close()

	if err := WaitForPostgres(ctx, db); err != nil {
		t.Fatalf("postgres not ready: %v", err)
	}
	if err := RollbackMigrations(ctx, db); err != nil {
		t.Fatalf("rollback: %v", err)
	}
	if err := ApplyMigrationFiles(ctx, db, "migrations/001_initial_schema.up.sql"); err != nil {
		t.Fatalf("migrate up: %v", err)
	}
	defer func() { _ = RollbackMigrations(ctx, db) }()

	st := NewPostgresStore(db)
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	userID := "usr_pg_conc"

	const workers = 50
	var wg sync.WaitGroup
	wg.Add(workers)
	errCh := make(chan error, workers)

	for i := 0; i < workers; i++ {
		i := i
		go func() {
			defer wg.Done()
			entry := model.LedgerEntry{
				ID:        fmt.Sprintf("led_pg_%d", i),
				UserID:    userID,
				Type:      model.EntryGrant,
				Amount:    1,
				RefKind:   "pg_conc",
				RefID:     fmt.Sprintf("ref_pg_%d", i),
				CreatedAt: now,
			}
			for attempt := 0; attempt < 8; attempt++ {
				bal, err := st.GetBalance(ctx, userID)
				version := int64(0)
				current := int64(0)
				if err == nil {
					version = bal.Version
					current = bal.Balance
				} else if err != ErrNotFound {
					errCh <- err
					return
				}
				entry.BalanceAfter = current + 1
				err = st.ApplyLedgerEntry(ctx, ApplyLedgerInput{
					Entry: entry, ExpectedVersion: version, NewBalance: entry.BalanceAfter,
				})
				if err == nil {
					return
				}
				if err != ErrVersionConflict {
					errCh <- err
					return
				}
			}
			errCh <- ErrVersionConflict
		}()
	}
	wg.Wait()
	close(errCh)
	for err := range errCh {
		t.Fatalf("postgres concurrent apply error = %v", err)
	}

	bal, err := st.GetBalance(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if bal.Balance != workers {
		t.Fatalf("balance = %d, want %d", bal.Balance, workers)
	}
}
