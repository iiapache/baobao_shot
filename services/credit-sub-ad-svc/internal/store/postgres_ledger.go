package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/lib/pq"
)

func (s *PostgresStore) GetBalance(ctx context.Context, userID string) (*model.Balance, error) {
	const q = `
SELECT user_id, balance, version, updated_at
FROM credit_balances
WHERE user_id = $1`
	row := s.db.QueryRowContext(ctx, q, userID)
	bal, err := scanBalance(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return bal, err
}

func (s *PostgresStore) GetLedgerByRef(ctx context.Context, refKind, refID string) (*model.LedgerEntry, error) {
	const q = `
SELECT id, user_id, type, amount, ref_kind, ref_id, balance_after, created_at
FROM credit_ledger
WHERE ref_kind = $1 AND ref_id = $2`
	row := s.db.QueryRowContext(ctx, q, refKind, refID)
	entry, err := scanLedgerEntry(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return entry, err
}

func (s *PostgresStore) ApplyLedgerEntry(ctx context.Context, in ApplyLedgerInput) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	now := in.Entry.CreatedAt.UTC()

	const updateBalance = `
UPDATE credit_balances
SET balance = $2, version = version + 1, updated_at = $3
WHERE user_id = $1 AND version = $4`
	res, err := tx.ExecContext(ctx, updateBalance,
		in.Entry.UserID,
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
		_, err = tx.ExecContext(ctx, insertBalance, in.Entry.UserID, in.NewBalance, now)
		if err != nil {
			var pqErr *pq.Error
			if errors.As(err, &pqErr) && pqErr.Code == "23505" {
				return ErrVersionConflict
			}
			return fmt.Errorf("insert balance: %w", err)
		}
	}

	const insertLedger = `
INSERT INTO credit_ledger (id, user_id, type, amount, ref_kind, ref_id, balance_after, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`
	_, err = tx.ExecContext(ctx, insertLedger,
		in.Entry.ID,
		in.Entry.UserID,
		string(in.Entry.Type),
		in.Entry.Amount,
		in.Entry.RefKind,
		in.Entry.RefID,
		in.Entry.BalanceAfter,
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

type rowScanner interface {
	Scan(dest ...any) error
}

func scanBalance(row rowScanner) (*model.Balance, error) {
	var bal model.Balance
	if err := row.Scan(&bal.UserID, &bal.Balance, &bal.Version, &bal.UpdatedAt); err != nil {
		return nil, err
	}
	bal.UpdatedAt = bal.UpdatedAt.UTC()
	return &bal, nil
}

func scanLedgerEntry(row rowScanner) (*model.LedgerEntry, error) {
	var entry model.LedgerEntry
	var entryType string
	if err := row.Scan(
		&entry.ID,
		&entry.UserID,
		&entryType,
		&entry.Amount,
		&entry.RefKind,
		&entry.RefID,
		&entry.BalanceAfter,
		&entry.CreatedAt,
	); err != nil {
		return nil, err
	}
	entry.Type = model.EntryType(entryType)
	entry.CreatedAt = entry.CreatedAt.UTC()
	return &entry, nil
}
