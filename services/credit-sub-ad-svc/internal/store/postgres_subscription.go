package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/lib/pq"
)

func (s *PostgresStore) GetSubscriptionByOriginalTransactionID(ctx context.Context, originalTransactionID string) (*model.Subscription, error) {
	const q = `
SELECT id, user_id, original_transaction_id, sku, period_start, period_end, state, auto_renew, last_event_at
FROM subscriptions
WHERE original_transaction_id = $1`
	row := s.db.QueryRowContext(ctx, q, originalTransactionID)
	sub, err := scanSubscription(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return sub, err
}

func (s *PostgresStore) GetLatestSubscriptionByUserID(ctx context.Context, userID string) (*model.Subscription, error) {
	const q = `
SELECT id, user_id, original_transaction_id, sku, period_start, period_end, state, auto_renew, last_event_at
FROM subscriptions
WHERE user_id = $1
ORDER BY last_event_at DESC
LIMIT 1`
	row := s.db.QueryRowContext(ctx, q, userID)
	sub, err := scanSubscription(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return sub, err
}

func (s *PostgresStore) CreateSubscription(ctx context.Context, sub model.Subscription) error {
	const q = `
INSERT INTO subscriptions (
	id, user_id, original_transaction_id, sku, period_start, period_end, state, auto_renew, last_event_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`
	_, err := s.db.ExecContext(ctx, q,
		sub.ID,
		sub.UserID,
		sub.OriginalTransactionID,
		sub.SKU,
		sub.PeriodStart.UTC(),
		sub.PeriodEnd.UTC(),
		string(sub.State),
		sub.AutoRenew,
		sub.LastEventAt.UTC(),
	)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return ErrDuplicateTransaction
		}
		return fmt.Errorf("insert subscription: %w", err)
	}
	return nil
}

func (s *PostgresStore) UpdateSubscription(ctx context.Context, sub model.Subscription) error {
	const q = `
UPDATE subscriptions
SET sku = $2,
    period_start = $3,
    period_end = $4,
    state = $5,
    auto_renew = $6,
    last_event_at = $7
WHERE id = $1`
	res, err := s.db.ExecContext(ctx, q,
		sub.ID,
		sub.SKU,
		sub.PeriodStart.UTC(),
		sub.PeriodEnd.UTC(),
		string(sub.State),
		sub.AutoRenew,
		sub.LastEventAt.UTC(),
	)
	if err != nil {
		return fmt.Errorf("update subscription: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) ListSubscriptionsForExpiryScan(ctx context.Context, now time.Time) ([]model.Subscription, error) {
	const q = `
SELECT id, user_id, original_transaction_id, sku, period_start, period_end, state, auto_renew, last_event_at
FROM subscriptions
WHERE state IN ('trial', 'active', 'grace')
  AND period_end <= $1
ORDER BY id`
	rows, err := s.db.QueryContext(ctx, q, now.UTC())
	if err != nil {
		return nil, fmt.Errorf("list subscriptions for expiry scan: %w", err)
	}
	defer rows.Close()

	var out []model.Subscription
	for rows.Next() {
		sub, err := scanSubscription(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *sub)
	}
	return out, rows.Err()
}

func scanSubscription(row rowScanner) (*model.Subscription, error) {
	var sub model.Subscription
	var state string
	if err := row.Scan(
		&sub.ID,
		&sub.UserID,
		&sub.OriginalTransactionID,
		&sub.SKU,
		&sub.PeriodStart,
		&sub.PeriodEnd,
		&state,
		&sub.AutoRenew,
		&sub.LastEventAt,
	); err != nil {
		return nil, err
	}
	sub.State = model.SubscriptionState(state)
	sub.PeriodStart = sub.PeriodStart.UTC()
	sub.PeriodEnd = sub.PeriodEnd.UTC()
	sub.LastEventAt = sub.LastEventAt.UTC()
	return &sub, nil
}
