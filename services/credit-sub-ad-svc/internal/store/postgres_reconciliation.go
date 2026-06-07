package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *PostgresStore) ListBalances(ctx context.Context) ([]model.Balance, error) {
	const q = `SELECT user_id, balance, version, updated_at FROM credit_balances ORDER BY user_id`
	rows, err := s.db.QueryContext(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("list balances: %w", err)
	}
	defer rows.Close()

	out := make([]model.Balance, 0)
	for rows.Next() {
		var bal model.Balance
		if err := rows.Scan(&bal.UserID, &bal.Balance, &bal.Version, &bal.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan balance: %w", err)
		}
		out = append(out, bal)
	}
	return out, rows.Err()
}

func (s *PostgresStore) ListHolds(ctx context.Context) ([]model.Hold, error) {
	const q = `
SELECT id, user_id, ai_task_id, amount, status, created_at
FROM credit_holds
ORDER BY created_at ASC, id ASC`
	rows, err := s.db.QueryContext(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("list holds: %w", err)
	}
	defer rows.Close()

	out := make([]model.Hold, 0)
	for rows.Next() {
		var hold model.Hold
		if err := rows.Scan(
			&hold.ID,
			&hold.UserID,
			&hold.AITaskID,
			&hold.Amount,
			&hold.Status,
			&hold.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan hold: %w", err)
		}
		out = append(out, hold)
	}
	return out, rows.Err()
}

func (s *PostgresStore) ListIAPReceipts(ctx context.Context) ([]model.IAPReceipt, error) {
	const q = `
SELECT id, user_id, transaction_id, original_transaction_id, product_id, signed_payload, verified_at, status
FROM iap_receipts
ORDER BY verified_at ASC, transaction_id ASC`
	rows, err := s.db.QueryContext(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("list iap receipts: %w", err)
	}
	defer rows.Close()

	out := make([]model.IAPReceipt, 0)
	for rows.Next() {
		var receipt model.IAPReceipt
		if err := rows.Scan(
			&receipt.ID,
			&receipt.UserID,
			&receipt.TransactionID,
			&receipt.OriginalTransactionID,
			&receipt.ProductID,
			&receipt.SignedPayload,
			&receipt.VerifiedAt,
			&receipt.Status,
		); err != nil {
			return nil, fmt.Errorf("scan iap receipt: %w", err)
		}
		out = append(out, receipt)
	}
	return out, rows.Err()
}

func (s *PostgresStore) ListLedgerByRefKind(ctx context.Context, refKind string) ([]model.LedgerEntry, error) {
	const q = `
SELECT id, user_id, type, amount, ref_kind, ref_id, balance_after, created_at
FROM credit_ledger
WHERE ref_kind = $1
ORDER BY created_at ASC, id ASC`
	rows, err := s.db.QueryContext(ctx, q, refKind)
	if err != nil {
		return nil, fmt.Errorf("list ledger by ref kind: %w", err)
	}
	defer rows.Close()

	out := make([]model.LedgerEntry, 0)
	for rows.Next() {
		entry, err := scanLedgerEntry(rows)
		if err != nil {
			return nil, fmt.Errorf("scan ledger entry: %w", err)
		}
		out = append(out, *entry)
	}
	return out, rows.Err()
}

func (s *PostgresStore) LatestLedgerByUser(ctx context.Context, userID string) (*model.LedgerEntry, error) {
	const q = `
SELECT id, user_id, type, amount, ref_kind, ref_id, balance_after, created_at
FROM credit_ledger
WHERE user_id = $1
ORDER BY created_at DESC, id DESC
LIMIT 1`
	row := s.db.QueryRowContext(ctx, q, userID)
	entry, err := scanLedgerEntry(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("latest ledger by user: %w", err)
	}
	return entry, nil
}

func (s *PostgresStore) SaveReconciliationRun(ctx context.Context, run model.ReconciliationRun) error {
	report := run.Report
	if report == nil {
		report = map[string]any{}
	}
	raw, err := json.Marshal(report)
	if err != nil {
		return fmt.Errorf("marshal reconciliation report: %w", err)
	}

	const q = `
INSERT INTO credit_reconciliation_runs (
	id, kind, period_start, period_end, status, discrepancy_count, report, created_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`
	_, err = s.db.ExecContext(ctx, q,
		run.ID,
		string(run.Kind),
		run.PeriodStart,
		run.PeriodEnd,
		string(run.Status),
		run.DiscrepancyCount,
		raw,
		run.CreatedAt,
	)
	if err != nil {
		return fmt.Errorf("save reconciliation run: %w", err)
	}
	return nil
}
