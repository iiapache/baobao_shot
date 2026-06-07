package reconciliation

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/google/uuid"
)

const alertKey = "credit_reconciliation"

// Discrepancy describes one reconciliation mismatch.
type Discrepancy struct {
	Domain   string `json:"domain"`
	RefKind  string `json:"refKind,omitempty"`
	RefID    string `json:"refId,omitempty"`
	Detail   string `json:"detail"`
	Expected int64  `json:"expected,omitempty"`
	Actual   int64  `json:"actual,omitempty"`
}

// Result is the outcome of one reconciliation run.
type Result struct {
	Run            model.ReconciliationRun
	Discrepancies  []Discrepancy
	HasDiscrepancy bool
}

// Service reconciles credits against IAP receipts, ad rewards, holds, and model costs.
type Service struct {
	store      store.ReconciliationStore
	adStore    store.AdRewardStore
	iapCatalog iap.ProductCatalog
	costSource CostMeteringSource
	now        func() time.Time
	newRunID   func() string
	alert      func(discrepancies []Discrepancy, run model.ReconciliationRun)
}

// NewService creates a reconciliation service.
func NewService(st store.Store, catalog iap.ProductCatalog, costSource CostMeteringSource) *Service {
	if catalog == nil {
		catalog = iap.DefaultProductCatalog
	}
	if costSource == nil {
		costSource = NopCostSource{}
	}
	return &Service{
		store:      st,
		adStore:    st,
		iapCatalog: catalog,
		costSource: costSource,
		now:        time.Now,
		newRunID:   func() string { return "recon_" + uuid.NewString()[:12] },
		alert:      defaultAlert,
	}
}

// SetNow overrides the clock (tests only).
func (s *Service) SetNow(fn func() time.Time) {
	if s != nil && fn != nil {
		s.now = fn
	}
}

// SetNewRunID overrides run id generation (tests only).
func (s *Service) SetNewRunID(fn func() string) {
	if s != nil && fn != nil {
		s.newRunID = fn
	}
}

// SetAlert overrides discrepancy alerting (tests only).
func (s *Service) SetAlert(fn func(discrepancies []Discrepancy, run model.ReconciliationRun)) {
	if s != nil && fn != nil {
		s.alert = fn
	}
}

// RunDaily executes reconciliation for the previous UTC day and persists an audit row.
func (s *Service) RunDaily(ctx context.Context) (Result, error) {
	end := dayStartUTC(s.now().UTC())
	start := end.AddDate(0, 0, -1)
	return s.run(ctx, model.ReconciliationDaily, start, end)
}

// RunOnce executes reconciliation for an arbitrary period (manual / tests).
func (s *Service) RunOnce(ctx context.Context, kind model.ReconciliationRunKind, start, end time.Time) (Result, error) {
	return s.run(ctx, kind, start.UTC(), end.UTC())
}

func (s *Service) run(ctx context.Context, kind model.ReconciliationRunKind, start, end time.Time) (Result, error) {
	if s == nil || s.store == nil {
		return Result{}, fmt.Errorf("reconciliation unavailable")
	}

	discrepancies := make([]Discrepancy, 0)
	discrepancies = append(discrepancies, s.checkBalances(ctx)...)
	discrepancies = append(discrepancies, s.checkHolds(ctx)...)
	discrepancies = append(discrepancies, s.checkIAP(ctx)...)
	discrepancies = append(discrepancies, s.checkAdRewards(ctx)...)
	discrepancies = append(discrepancies, s.checkModelCost(ctx, start, end)...)

	status := model.ReconciliationOK
	if len(discrepancies) > 0 {
		status = model.ReconciliationDiscrepancy
	}

	report := map[string]any{
		"periodStart":    start.Format(time.RFC3339),
		"periodEnd":      end.Format(time.RFC3339),
		"discrepancies":  discrepancies,
		"checks":         []string{"balance", "hold", "iap", "ad", "model_cost"},
	}
	run := model.ReconciliationRun{
		ID:               s.newRunID(),
		Kind:             kind,
		PeriodStart:      start,
		PeriodEnd:        end,
		Status:           status,
		DiscrepancyCount: len(discrepancies),
		Report:           report,
		CreatedAt:        s.now().UTC(),
	}
	if err := s.store.SaveReconciliationRun(ctx, run); err != nil {
		return Result{}, err
	}

	if len(discrepancies) > 0 && s.alert != nil {
		s.alert(discrepancies, run)
	}

	return Result{
		Run:            run,
		Discrepancies:  discrepancies,
		HasDiscrepancy: len(discrepancies) > 0,
	}, nil
}

func (s *Service) checkBalances(ctx context.Context) []Discrepancy {
	balances, err := s.store.ListBalances(ctx)
	if err != nil {
		return []Discrepancy{{Domain: "balance", Detail: err.Error()}}
	}

	out := make([]Discrepancy, 0)
	for _, bal := range balances {
		latest, err := s.store.LatestLedgerByUser(ctx, bal.UserID)
		if errors.Is(err, store.ErrNotFound) {
			if bal.Balance != 0 {
				out = append(out, Discrepancy{
					Domain:   "balance",
					RefID:    bal.UserID,
					Detail:   "balance without ledger history",
					Expected: 0,
					Actual:   bal.Balance,
				})
			}
			continue
		}
		if err != nil {
			out = append(out, Discrepancy{Domain: "balance", RefID: bal.UserID, Detail: err.Error()})
			continue
		}
		if latest.BalanceAfter != bal.Balance {
			out = append(out, Discrepancy{
				Domain:   "balance",
				RefID:    bal.UserID,
				Detail:   "balance does not match latest ledger balance_after",
				Expected: latest.BalanceAfter,
				Actual:   bal.Balance,
			})
		}
	}
	return out
}

func (s *Service) checkHolds(ctx context.Context) []Discrepancy {
	holds, err := s.store.ListHolds(ctx)
	if err != nil {
		return []Discrepancy{{Domain: "hold", Detail: err.Error()}}
	}

	commits, err := s.store.ListLedgerByRefKind(ctx, credit.RefKindAITaskCommit)
	if err != nil {
		return []Discrepancy{{Domain: "hold", Detail: err.Error()}}
	}
	releases, err := s.store.ListLedgerByRefKind(ctx, credit.RefKindAITaskRelease)
	if err != nil {
		return []Discrepancy{{Domain: "hold", Detail: err.Error()}}
	}
	commitByTask := indexLedgerByRefID(commits)
	releaseByTask := indexLedgerByRefID(releases)

	out := make([]Discrepancy, 0)
	for _, hold := range holds {
		switch hold.Status {
		case model.HoldStatusCommitted:
			entry, ok := commitByTask[hold.AITaskID]
			if !ok {
				out = append(out, Discrepancy{
					Domain:  "hold",
					RefKind: credit.RefKindAITaskCommit,
					RefID:   hold.AITaskID,
					Detail:  "committed hold missing consume ledger",
				})
				continue
			}
			if entry.Amount != hold.Amount {
				out = append(out, Discrepancy{
					Domain:   "hold",
					RefKind:  credit.RefKindAITaskCommit,
					RefID:    hold.AITaskID,
					Detail:   "commit ledger amount mismatch",
					Expected: hold.Amount,
					Actual:   entry.Amount,
				})
			}
		case model.HoldStatusReleased:
			entry, ok := releaseByTask[hold.AITaskID]
			if !ok {
				out = append(out, Discrepancy{
					Domain:  "hold",
					RefKind: credit.RefKindAITaskRelease,
					RefID:   hold.AITaskID,
					Detail:  "released hold missing refund ledger",
				})
				continue
			}
			if entry.Amount != hold.Amount {
				out = append(out, Discrepancy{
					Domain:   "hold",
					RefKind:  credit.RefKindAITaskRelease,
					RefID:    hold.AITaskID,
					Detail:   "release ledger amount mismatch",
					Expected: hold.Amount,
					Actual:   entry.Amount,
				})
			}
		}
	}
	return out
}

func (s *Service) checkIAP(ctx context.Context) []Discrepancy {
	receipts, err := s.store.ListIAPReceipts(ctx)
	if err != nil {
		return []Discrepancy{{Domain: "iap", Detail: err.Error()}}
	}
	ledgerEntries, err := s.store.ListLedgerByRefKind(ctx, "iap")
	if err != nil {
		return []Discrepancy{{Domain: "iap", Detail: err.Error()}}
	}
	ledgerByTx := indexLedgerByRefID(ledgerEntries)

	out := make([]Discrepancy, 0)
	seenLedger := make(map[string]struct{}, len(ledgerEntries))
	for _, receipt := range receipts {
		if receipt.Status != model.IAPReceiptVerified {
			continue
		}
		entry, ok := ledgerByTx[receipt.TransactionID]
		if !ok {
			out = append(out, Discrepancy{
				Domain:  "iap",
				RefKind: "iap",
				RefID:   receipt.TransactionID,
				Detail:  "verified receipt missing grant ledger",
			})
			continue
		}
		seenLedger[receipt.TransactionID] = struct{}{}
		expected, ok := s.iapCatalog.CreditsForProduct(receipt.ProductID)
		if !ok {
			out = append(out, Discrepancy{
				Domain:  "iap",
				RefKind: "iap",
				RefID:   receipt.TransactionID,
				Detail:  "unknown product in receipt",
			})
			continue
		}
		if entry.Amount != expected {
			out = append(out, Discrepancy{
				Domain:   "iap",
				RefKind:  "iap",
				RefID:    receipt.TransactionID,
				Detail:   "grant amount mismatch",
				Expected: expected,
				Actual:   entry.Amount,
			})
		}
	}
	for _, entry := range ledgerEntries {
		if _, ok := seenLedger[entry.RefID]; ok {
			continue
		}
		out = append(out, Discrepancy{
			Domain:  "iap",
			RefKind: "iap",
			RefID:   entry.RefID,
			Detail:  "ledger grant without verified receipt",
		})
	}
	return out
}

func (s *Service) checkAdRewards(ctx context.Context) []Discrepancy {
	if s.adStore == nil {
		return nil
	}
	rewards, err := s.adStore.ListAdRewards(ctx)
	if err != nil {
		return []Discrepancy{{Domain: "ad", Detail: err.Error()}}
	}
	ledgerEntries, err := s.store.ListLedgerByRefKind(ctx, "ad_reward")
	if err != nil {
		return []Discrepancy{{Domain: "ad", Detail: err.Error()}}
	}
	ledgerByRef := indexLedgerByRefID(ledgerEntries)

	out := make([]Discrepancy, 0)
	seenLedger := make(map[string]struct{}, len(ledgerEntries))
	for _, reward := range rewards {
		refID := model.AdRewardLedgerRefID(reward.Network, reward.Signature)
		entry, ok := ledgerByRef[refID]
		if !ok {
			out = append(out, Discrepancy{
				Domain:  "ad",
				RefKind: "ad_reward",
				RefID:   refID,
				Detail:  "ad reward missing grant ledger",
			})
			continue
		}
		seenLedger[refID] = struct{}{}
		if entry.Amount != reward.GrantedCredits {
			out = append(out, Discrepancy{
				Domain:   "ad",
				RefKind:  "ad_reward",
				RefID:    refID,
				Detail:   "ad grant amount mismatch",
				Expected: reward.GrantedCredits,
				Actual:   entry.Amount,
			})
		}
	}
	for _, entry := range ledgerEntries {
		if _, ok := seenLedger[entry.RefID]; ok {
			continue
		}
		out = append(out, Discrepancy{
			Domain:  "ad",
			RefKind: "ad_reward",
			RefID:   entry.RefID,
			Detail:  "ledger ad grant without ad_rewards row",
		})
	}
	return out
}

func (s *Service) checkModelCost(ctx context.Context, start, end time.Time) []Discrepancy {
	entries, err := s.store.ListLedgerByRefKind(ctx, credit.RefKindAITaskCommit)
	if err != nil {
		return []Discrepancy{{Domain: "model_cost", Detail: err.Error()}}
	}

	var ledgerTotal int64
	for _, entry := range entries {
		if entry.CreatedAt.Before(start) || !entry.CreatedAt.Before(end) {
			continue
		}
		ledgerTotal += entry.Amount
	}

	remoteTotal, err := s.costSource.CreditsConsumedInPeriod(ctx, start, end)
	if errors.Is(err, ErrCostSourceUnavailable) {
		return nil
	}
	if err != nil {
		return []Discrepancy{{Domain: "model_cost", Detail: err.Error()}}
	}

	if remoteTotal != ledgerTotal {
		return []Discrepancy{{
			Domain:   "model_cost",
			Detail:   "ledger ai_task_commit total differs from ai-dispatch cost metering",
			Expected: remoteTotal,
			Actual:   ledgerTotal,
		}}
	}
	return nil
}

func indexLedgerByRefID(entries []model.LedgerEntry) map[string]model.LedgerEntry {
	out := make(map[string]model.LedgerEntry, len(entries))
	for _, entry := range entries {
		out[entry.RefID] = entry
	}
	return out
}

func dayStartUTC(t time.Time) time.Time {
	t = t.UTC()
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func defaultAlert(discrepancies []Discrepancy, run model.ReconciliationRun) {
	slog.Error("credit reconciliation discrepancy",
		"alert", alertKey,
		"run_id", run.ID,
		"kind", run.Kind,
		"discrepancy_count", len(discrepancies),
		"discrepancies", discrepancies,
	)
}
