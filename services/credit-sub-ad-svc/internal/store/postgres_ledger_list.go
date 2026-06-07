package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *PostgresStore) ListLedgerEntries(ctx context.Context, in ListLedgerInput) (ListLedgerResult, error) {
	limit := NormalizeLedgerLimit(in.Limit)
	cursorTime, cursorID, err := ParseLedgerCursor(in.Cursor)
	if err != nil {
		return ListLedgerResult{}, err
	}

	fetchLimit := limit + 1
	var rows *sql.Rows
	if cursorTime.IsZero() {
		const q = `
SELECT id, user_id, type, amount, ref_kind, ref_id, balance_after, created_at
FROM credit_ledger
WHERE user_id = $1
ORDER BY created_at DESC, id DESC
LIMIT $2`
		rows, err = s.db.QueryContext(ctx, q, in.UserID, fetchLimit)
	} else {
		const q = `
SELECT id, user_id, type, amount, ref_kind, ref_id, balance_after, created_at
FROM credit_ledger
WHERE user_id = $1
  AND (created_at < $2 OR (created_at = $2 AND id < $3))
ORDER BY created_at DESC, id DESC
LIMIT $4`
		rows, err = s.db.QueryContext(ctx, q, in.UserID, cursorTime, cursorID, fetchLimit)
	}
	if err != nil {
		return ListLedgerResult{}, fmt.Errorf("list ledger: %w", err)
	}
	defer rows.Close()

	items := make([]model.LedgerEntry, 0, fetchLimit)
	for rows.Next() {
		entry, scanErr := scanLedgerEntry(rows)
		if scanErr != nil {
			return ListLedgerResult{}, scanErr
		}
		items = append(items, *entry)
	}
	if err := rows.Err(); err != nil {
		return ListLedgerResult{}, err
	}

	result := ListLedgerResult{}
	if len(items) > limit {
		result.Items = items[:limit]
		result.NextCursor = EncodeLedgerCursor(items[limit-1])
		return result, nil
	}
	result.Items = items
	return result, nil
}

func (s *PostgresStore) HasSignedIn(ctx context.Context, userID string, date time.Time) (bool, error) {
	const q = `SELECT EXISTS(SELECT 1 FROM sign_ins WHERE user_id = $1 AND date = $2::date)`
	day := date.UTC()
	dayDate := time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, time.UTC)
	var exists bool
	err := s.db.QueryRowContext(ctx, q, userID, dayDate).Scan(&exists)
	return exists, err
}
