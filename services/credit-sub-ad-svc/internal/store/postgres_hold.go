package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/lib/pq"
)

func (s *PostgresStore) GetHoldByID(ctx context.Context, holdID string) (*model.Hold, error) {
	const q = `
SELECT id, user_id, ai_task_id, amount, status, created_at
FROM credit_holds
WHERE id = $1`
	row := s.db.QueryRowContext(ctx, q, holdID)
	hold, err := scanHold(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return hold, err
}

func (s *PostgresStore) GetHoldByAITaskID(ctx context.Context, aiTaskID string) (*model.Hold, error) {
	const q = `
SELECT id, user_id, ai_task_id, amount, status, created_at
FROM credit_holds
WHERE ai_task_id = $1`
	row := s.db.QueryRowContext(ctx, q, aiTaskID)
	hold, err := scanHold(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return hold, err
}

func (s *PostgresStore) CreateHoldWithDebit(ctx context.Context, in CreateHoldInput) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	now := in.Hold.CreatedAt.UTC()

	const updateBalance = `
UPDATE credit_balances
SET balance = $2, version = version + 1, updated_at = $3
WHERE user_id = $1 AND version = $4`
	res, err := tx.ExecContext(ctx, updateBalance,
		in.Hold.UserID,
		in.NewBalance,
		now,
		in.ExpectedVersion,
	)
	if err != nil {
		return fmt.Errorf("update balance: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		if in.ExpectedVersion != 0 {
			return ErrVersionConflict
		}
		const insertBalance = `
INSERT INTO credit_balances (user_id, balance, version, updated_at)
VALUES ($1, $2, 1, $3)`
		_, err = tx.ExecContext(ctx, insertBalance, in.Hold.UserID, in.NewBalance, now)
		if err != nil {
			var pqErr *pq.Error
			if errors.As(err, &pqErr) && pqErr.Code == "23505" {
				return ErrVersionConflict
			}
			return fmt.Errorf("insert balance: %w", err)
		}
	}

	const insertHold = `
INSERT INTO credit_holds (id, user_id, ai_task_id, amount, status, created_at)
VALUES ($1, $2, $3, $4, $5, $6)`
	_, err = tx.ExecContext(ctx, insertHold,
		in.Hold.ID,
		in.Hold.UserID,
		in.Hold.AITaskID,
		in.Hold.Amount,
		string(in.Hold.Status),
		now,
	)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return ErrDuplicateHold
		}
		return fmt.Errorf("insert hold: %w", err)
	}

	return tx.Commit()
}

func (s *PostgresStore) CommitHoldWithLedger(ctx context.Context, in CommitHoldInput) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	const updateHold = `
UPDATE credit_holds
SET status = 'committed'
WHERE id = $1 AND status = 'held'`
	res, err := tx.ExecContext(ctx, updateHold, in.HoldID)
	if err != nil {
		return fmt.Errorf("update hold: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		hold, fetchErr := s.GetHoldByID(ctx, in.HoldID)
		if errors.Is(fetchErr, ErrNotFound) {
			return ErrNotFound
		}
		if fetchErr != nil {
			return fetchErr
		}
		if hold.Status != model.HoldStatusHeld {
			return ErrHoldNotHeld
		}
		return ErrHoldNotHeld
	}

	now := in.LedgerEntry.CreatedAt.UTC()
	const insertLedger = `
INSERT INTO credit_ledger (id, user_id, type, amount, ref_kind, ref_id, balance_after, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`
	_, err = tx.ExecContext(ctx, insertLedger,
		in.LedgerEntry.ID,
		in.LedgerEntry.UserID,
		string(in.LedgerEntry.Type),
		in.LedgerEntry.Amount,
		in.LedgerEntry.RefKind,
		in.LedgerEntry.RefID,
		in.LedgerEntry.BalanceAfter,
		now,
	)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return ErrDuplicateRef
		}
		return fmt.Errorf("insert ledger: %w", err)
	}

	return tx.Commit()
}

func (s *PostgresStore) ReleaseHoldWithRefund(ctx context.Context, in ReleaseHoldInput) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	const updateHold = `
UPDATE credit_holds
SET status = 'released'
WHERE id = $1 AND status = 'held'`
	res, err := tx.ExecContext(ctx, updateHold, in.HoldID)
	if err != nil {
		return fmt.Errorf("update hold: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		hold, fetchErr := s.GetHoldByID(ctx, in.HoldID)
		if errors.Is(fetchErr, ErrNotFound) {
			return ErrNotFound
		}
		if fetchErr != nil {
			return fetchErr
		}
		if hold.Status != model.HoldStatusHeld {
			return ErrHoldNotHeld
		}
		return ErrHoldNotHeld
	}

	now := in.LedgerEntry.CreatedAt.UTC()
	const updateBalance = `
UPDATE credit_balances
SET balance = $2, version = version + 1, updated_at = $3
WHERE user_id = $1 AND version = $4`
	res, err = tx.ExecContext(ctx, updateBalance,
		in.LedgerEntry.UserID,
		in.NewBalance,
		now,
		in.ExpectedVersion,
	)
	if err != nil {
		return fmt.Errorf("update balance: %w", err)
	}
	n, err = res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrVersionConflict
	}

	const insertLedger = `
INSERT INTO credit_ledger (id, user_id, type, amount, ref_kind, ref_id, balance_after, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`
	_, err = tx.ExecContext(ctx, insertLedger,
		in.LedgerEntry.ID,
		in.LedgerEntry.UserID,
		string(in.LedgerEntry.Type),
		in.LedgerEntry.Amount,
		in.LedgerEntry.RefKind,
		in.LedgerEntry.RefID,
		in.LedgerEntry.BalanceAfter,
		now,
	)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return ErrDuplicateRef
		}
		return fmt.Errorf("insert ledger: %w", err)
	}

	return tx.Commit()
}

func scanHold(row rowScanner) (*model.Hold, error) {
	var hold model.Hold
	var status string
	if err := row.Scan(
		&hold.ID,
		&hold.UserID,
		&hold.AITaskID,
		&hold.Amount,
		&status,
		&hold.CreatedAt,
	); err != nil {
		return nil, err
	}
	hold.Status = model.HoldStatus(status)
	hold.CreatedAt = hold.CreatedAt.UTC()
	return &hold, nil
}
