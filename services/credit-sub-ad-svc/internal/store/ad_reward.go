package store

import (
	"context"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// AdRewardStore reads and writes incentivized ad reward records.
type AdRewardStore interface {
	ListAdRewards(ctx context.Context) ([]model.AdReward, error)
	GetAdRewardByNetworkSig(ctx context.Context, network, signature string) (*model.AdReward, error)
	CreateAdReward(ctx context.Context, reward model.AdReward) (inserted bool, err error)
	CountAdRewardsByUserDay(ctx context.Context, userID string, day time.Time) (int, error)
}
