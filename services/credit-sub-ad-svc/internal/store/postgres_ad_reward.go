package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *PostgresStore) GetAdRewardByNetworkSig(ctx context.Context, network, signature string) (*model.AdReward, error) {
	const q = `
SELECT id, user_id, network, placement_id, signature, granted_credits, created_at
FROM ad_rewards
WHERE network = $1 AND signature = $2`
	row := s.db.QueryRowContext(ctx, q, network, signature)
	reward, err := scanAdReward(row)
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get ad reward: %w", err)
	}
	return reward, nil
}

func (s *PostgresStore) CreateAdReward(ctx context.Context, reward model.AdReward) (bool, error) {
	const q = `
INSERT INTO ad_rewards (id, user_id, network, placement_id, signature, granted_credits, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (network, signature) DO NOTHING
RETURNING id`
	var insertedID string
	err := s.db.QueryRowContext(ctx, q,
		reward.ID,
		reward.UserID,
		reward.Network,
		reward.PlacementID,
		reward.Signature,
		reward.GrantedCredits,
		reward.CreatedAt,
	).Scan(&insertedID)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("create ad reward: %w", err)
	}
	return true, nil
}

func (s *PostgresStore) CountAdRewardsByUserDay(ctx context.Context, userID string, day time.Time) (int, error) {
	const q = `
SELECT COUNT(*)
FROM ad_rewards
WHERE user_id = $1
  AND created_at >= $2::timestamptz
  AND created_at < $3::timestamptz`
	start := utcDate(day)
	end := start.AddDate(0, 0, 1)
	var count int
	if err := s.db.QueryRowContext(ctx, q, userID, start, end).Scan(&count); err != nil {
		return 0, fmt.Errorf("count ad rewards: %w", err)
	}
	return count, nil
}

func (s *PostgresStore) ListAdRewards(ctx context.Context) ([]model.AdReward, error) {
	const q = `
SELECT id, user_id, network, placement_id, signature, granted_credits, created_at
FROM ad_rewards
ORDER BY created_at ASC, id ASC`
	rows, err := s.db.QueryContext(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("list ad rewards: %w", err)
	}
	defer rows.Close()

	out := make([]model.AdReward, 0)
	for rows.Next() {
		reward, err := scanAdReward(rows)
		if err != nil {
			return nil, fmt.Errorf("scan ad reward: %w", err)
		}
		out = append(out, *reward)
	}
	return out, rows.Err()
}

func scanAdReward(row interface {
	Scan(dest ...any) error
}) (*model.AdReward, error) {
	var reward model.AdReward
	if err := row.Scan(
		&reward.ID,
		&reward.UserID,
		&reward.Network,
		&reward.PlacementID,
		&reward.Signature,
		&reward.GrantedCredits,
		&reward.CreatedAt,
	); err != nil {
		return nil, err
	}
	return &reward, nil
}
