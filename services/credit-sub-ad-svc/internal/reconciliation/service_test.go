package reconciliation

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/idempotency"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func TestReconciliationCleanState(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	now := time.Date(2026, 6, 7, 1, 0, 0, 0, time.UTC)

	_, err := ledger.Grant(ctx, "usr_1", 100, "signup", "usr_1")
	if err != nil {
		t.Fatal(err)
	}

	svc := newTestService(st, now, nil)
	result, err := svc.RunOnce(ctx, model.ReconciliationManual, now.AddDate(0, 0, -1), now)
	if err != nil {
		t.Fatalf("RunOnce() error = %v", err)
	}
	if result.HasDiscrepancy {
		t.Fatalf("unexpected discrepancies: %+v", result.Discrepancies)
	}
	if result.Run.Status != model.ReconciliationOK {
		t.Fatalf("status = %s", result.Run.Status)
	}
	if st.ReconciliationRunCount() != 1 {
		t.Fatalf("audit runs = %d, want 1", st.ReconciliationRunCount())
	}
}

func TestReconciliationIAPMissingLedger(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	now := time.Date(2026, 6, 7, 1, 0, 0, 0, time.UTC)

	if err := st.CreateIAPReceipt(ctx, model.IAPReceipt{
		ID:            "iap_1",
		UserID:        "usr_iap",
		TransactionID: "tx_missing_ledger",
		ProductID:     "credit_pack_60",
		Status:        model.IAPReceiptVerified,
		VerifiedAt:    now,
	}); err != nil {
		t.Fatal(err)
	}

	alerted := false
	svc := newTestService(st, now, func(_ []Discrepancy, _ model.ReconciliationRun) {
		alerted = true
	})
	result, err := svc.RunOnce(ctx, model.ReconciliationManual, now.AddDate(0, 0, -1), now)
	if err != nil {
		t.Fatal(err)
	}
	if !result.HasDiscrepancy {
		t.Fatal("expected discrepancy")
	}
	if !alerted {
		t.Fatal("expected alert callback")
	}
	if result.Run.Status != model.ReconciliationDiscrepancy {
		t.Fatalf("status = %s", result.Run.Status)
	}
}

func TestReconciliationAdRewardMismatch(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	now := time.Date(2026, 6, 7, 1, 0, 0, 0, time.UTC)

	if _, err := st.CreateAdReward(ctx, model.AdReward{
		ID:             "ad_1",
		UserID:         "usr_ad",
		Network:        "pangle",
		Signature:      "sig_abc",
		GrantedCredits: 20,
		CreatedAt:      now,
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := ledger.Grant(ctx, "usr_ad", 15, "ad_reward", model.AdRewardLedgerRefID("pangle", "sig_abc")); err != nil {
		t.Fatal(err)
	}

	svc := newTestService(st, now, nil)
	result, err := svc.RunOnce(ctx, model.ReconciliationManual, now.AddDate(0, 0, -1), now)
	if err != nil {
		t.Fatal(err)
	}
	if !result.HasDiscrepancy {
		t.Fatal("expected ad amount mismatch")
	}
	found := false
	for _, d := range result.Discrepancies {
		if d.Domain == "ad" {
			found = true
		}
	}
	if !found {
		t.Fatalf("discrepancies = %+v", result.Discrepancies)
	}
}

func TestReconciliationModelCostMismatch(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	saga := credit.NewSagaService(st, idempotency.NewMemoryStore())
	now := time.Date(2026, 6, 7, 12, 0, 0, 0, time.UTC)
	start := now.AddDate(0, 0, -1)

	if _, err := ledger.Grant(ctx, "usr_ai", 100, "signup", "usr_ai"); err != nil {
		t.Fatal(err)
	}

	hold, err := saga.Hold(ctx, credit.HoldInput{
		UserID: "usr_ai", AITaskID: "tsk_1", Amount: 8,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := saga.Commit(ctx, credit.SettleInput{HoldID: hold.HoldID, AITaskID: "tsk_1"}); err != nil {
		t.Fatal(err)
	}

	svcWithCost := NewService(st, iap.DefaultProductCatalog, StaticCostSource{Total: 99})
	svcWithCost.SetNow(func() time.Time { return now.Add(time.Hour) })
	svcWithCost.SetNewRunID(func() string { return "recon_test" })

	result, err := svcWithCost.RunOnce(ctx, model.ReconciliationManual, start, now)
	if err != nil {
		t.Fatal(err)
	}
	if !result.HasDiscrepancy {
		t.Fatal("expected model cost mismatch")
	}
}

func TestHTTPCostMeteringSourceWeeklyReport(t *testing.T) {
	weekStart := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/internal/v1/cost-metering/weekly-report" {
			t.Fatalf("path = %s", r.URL.Path)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"weekStart":    weekStart,
			"weekEnd":      weekStart.AddDate(0, 0, 7),
			"totalCredits": int64(42),
		})
	}))
	defer server.Close()

	source := NewHTTPCostMeteringSource(server.URL).(*HTTPCostMeteringSource)
	total, err := source.CreditsConsumedInPeriod(context.Background(), weekStart, weekStart.AddDate(0, 0, 7))
	if err != nil {
		t.Fatal(err)
	}
	if total != 42 {
		t.Fatalf("total = %d", total)
	}
}

func TestCronRunOnce(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	now := time.Date(2026, 6, 7, 1, 0, 0, 0, time.UTC)
	svc := newTestService(st, now, nil)
	cron := NewCron(svc, time.Hour)

	result, err := cron.RunOnce(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if result.HasDiscrepancy {
		t.Fatalf("discrepancies = %+v", result.Discrepancies)
	}
}

func newTestService(st *store.MemoryStore, now time.Time, alert func([]Discrepancy, model.ReconciliationRun)) *Service {
	svc := NewService(st, iap.DefaultProductCatalog, NopCostSource{})
	svc.SetNow(func() time.Time { return now })
	svc.SetNewRunID(func() string { return "recon_test" })
	if alert != nil {
		svc.SetAlert(alert)
	}
	return svc
}
