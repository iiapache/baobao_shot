package store

import (
	"context"
	"fmt"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func adRewardKey(network, signature string) string {
	return fmt.Sprintf("%s\x00%s", network, signature)
}

func (s *MemoryStore) GetAdRewardByNetworkSig(_ context.Context, network, signature string) (*model.AdReward, error) {
	key := adRewardKey(network, signature)
	s.mu.RLock()
	defer s.mu.RUnlock()
	rewardID, ok := s.adByNetworkSig[key]
	if !ok {
		return nil, ErrNotFound
	}
	reward, ok := s.adRewards[rewardID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneAdReward(reward), nil
}

func (s *MemoryStore) CreateAdReward(_ context.Context, reward model.AdReward) (bool, error) {
	key := adRewardKey(reward.Network, reward.Signature)
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.adByNetworkSig[key]; exists {
		return false, nil
	}
	cloned := cloneAdReward(&reward)
	s.adRewards[reward.ID] = cloned
	s.adByNetworkSig[key] = reward.ID
	return true, nil
}

func (s *MemoryStore) CountAdRewardsByUserDay(_ context.Context, userID string, day time.Time) (int, error) {
	start := utcDate(day)
	end := start.AddDate(0, 0, 1)
	s.mu.RLock()
	defer s.mu.RUnlock()
	count := 0
	for _, reward := range s.adRewards {
		if reward.UserID != userID {
			continue
		}
		created := reward.CreatedAt.UTC()
		if !created.Before(start) && created.Before(end) {
			count++
		}
	}
	return count, nil
}

func (s *MemoryStore) ListAdRewards(_ context.Context) ([]model.AdReward, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]model.AdReward, 0, len(s.adRewards))
	for _, reward := range s.adRewards {
		out = append(out, *cloneAdReward(reward))
	}
	return out, nil
}

func cloneAdReward(reward *model.AdReward) *model.AdReward {
	if reward == nil {
		return nil
	}
	out := *reward
	return &out
}
