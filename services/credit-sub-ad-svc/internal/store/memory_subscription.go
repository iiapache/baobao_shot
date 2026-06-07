package store

import (
	"context"
	"sort"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *MemoryStore) GetSubscriptionByOriginalTransactionID(_ context.Context, originalTransactionID string) (*model.Subscription, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	subID, ok := s.subByOriginalTx[originalTransactionID]
	if !ok {
		return nil, ErrNotFound
	}
	sub, ok := s.subscriptions[subID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneSubscription(sub), nil
}

func (s *MemoryStore) GetLatestSubscriptionByUserID(_ context.Context, userID string) (*model.Subscription, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	ids := s.subscriptionsByUser[userID]
	if len(ids) == 0 {
		return nil, ErrNotFound
	}

	var latest *model.Subscription
	for _, id := range ids {
		sub, ok := s.subscriptions[id]
		if !ok {
			continue
		}
		if latest == nil || sub.LastEventAt.After(latest.LastEventAt) {
			latest = sub
		}
	}
	if latest == nil {
		return nil, ErrNotFound
	}
	return cloneSubscription(latest), nil
}

func (s *MemoryStore) CreateSubscription(_ context.Context, sub model.Subscription) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.subByOriginalTx[sub.OriginalTransactionID]; exists {
		return ErrDuplicateTransaction
	}
	cloned := cloneSubscription(&sub)
	s.subscriptions[sub.ID] = cloned
	s.subByOriginalTx[sub.OriginalTransactionID] = sub.ID
	s.subscriptionsByUser[sub.UserID] = append(s.subscriptionsByUser[sub.UserID], sub.ID)
	return nil
}

func (s *MemoryStore) UpdateSubscription(_ context.Context, sub model.Subscription) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.subscriptions[sub.ID]; !ok {
		return ErrNotFound
	}
	s.subscriptions[sub.ID] = cloneSubscription(&sub)
	return nil
}

func (s *MemoryStore) ListSubscriptionsForExpiryScan(_ context.Context, now time.Time) ([]model.Subscription, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var out []model.Subscription
	for _, sub := range s.subscriptions {
		switch sub.State {
		case model.SubscriptionTrial, model.SubscriptionActive, model.SubscriptionGrace:
			if !now.After(sub.PeriodEnd) {
				continue
			}
			out = append(out, *cloneSubscription(sub))
		}
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].ID < out[j].ID
	})
	return out, nil
}

func cloneSubscription(sub *model.Subscription) *model.Subscription {
	if sub == nil {
		return nil
	}
	out := *sub
	out.PeriodStart = sub.PeriodStart.UTC()
	out.PeriodEnd = sub.PeriodEnd.UTC()
	out.LastEventAt = sub.LastEventAt.UTC()
	return &out
}
