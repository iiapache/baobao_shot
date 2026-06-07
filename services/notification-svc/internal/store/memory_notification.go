package store

import (
	"context"
	"encoding/json"
	"sort"
	"strings"
	"time"

	"github.com/baobao/notification-svc/internal/model"
)

func (s *MemoryStore) InsertNotification(_ context.Context, in InsertNotificationInput) (*model.Notification, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.notifications == nil {
		s.notifications = make(map[string]model.Notification)
	}

	payload := in.Payload
	if len(payload) == 0 {
		payload = json.RawMessage(`{}`)
	}
	createdAt := in.CreatedAt
	if createdAt.IsZero() {
		createdAt = time.Now().UTC()
	}

	n := model.Notification{
		ID:        in.ID,
		UserID:    in.UserID,
		Category:  in.Category,
		Payload:   payload,
		CreatedAt: createdAt,
	}
	s.notifications[in.ID] = n
	out := n
	return &out, nil
}

func (s *MemoryStore) ListNotifications(_ context.Context, in ListNotificationsInput) (ListNotificationsResult, error) {
	limit := NormalizeNotificationLimit(in.Limit)
	cursorTime, cursorID, err := ParseNotificationCursor(in.Cursor)
	if err != nil {
		return ListNotificationsResult{}, err
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	var items []model.Notification
	for _, n := range s.notifications {
		if n.UserID != in.UserID {
			continue
		}
		items = append(items, n)
	}

	sort.Slice(items, func(i, j int) bool {
		if items[i].CreatedAt.Equal(items[j].CreatedAt) {
			return items[i].ID > items[j].ID
		}
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})

	if !cursorTime.IsZero() {
		filtered := items[:0]
		for _, n := range items {
			if n.CreatedAt.Before(cursorTime) {
				filtered = append(filtered, n)
				continue
			}
			if n.CreatedAt.Equal(cursorTime) && n.ID < cursorID {
				filtered = append(filtered, n)
			}
		}
		items = filtered
	}

	result := ListNotificationsResult{}
	if len(items) > limit {
		page := items[:limit]
		result.Items = append(result.Items, page...)
		result.NextCursor = EncodeNotificationCursor(page[len(page)-1])
		return result, nil
	}
	result.Items = append(result.Items, items...)
	return result, nil
}

func (s *MemoryStore) CountUnreadNotifications(_ context.Context, userID string) (int64, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var count int64
	for _, n := range s.notifications {
		if n.UserID == userID && n.ReadAt == nil {
			count++
		}
	}
	return count, nil
}

func (s *MemoryStore) MarkNotificationsRead(_ context.Context, in MarkNotificationsReadInput) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	readAt := in.ReadAt
	if readAt.IsZero() {
		readAt = time.Now().UTC()
	}

	var marked int64
	if in.All || len(in.IDs) == 0 {
		for id, n := range s.notifications {
			if n.UserID != in.UserID || n.ReadAt != nil {
				continue
			}
			n.ReadAt = &readAt
			s.notifications[id] = n
			marked++
		}
		return marked, nil
	}

	idSet := make(map[string]struct{}, len(in.IDs))
	for _, id := range in.IDs {
		id = strings.TrimSpace(id)
		if id != "" {
			idSet[id] = struct{}{}
		}
	}

	for id := range idSet {
		n, ok := s.notifications[id]
		if !ok || n.UserID != in.UserID || n.ReadAt != nil {
			continue
		}
		n.ReadAt = &readAt
		s.notifications[id] = n
		marked++
	}
	return marked, nil
}

func (s *MemoryStore) ListSubscriptionRows(_ context.Context, userID string) ([]model.NotificationSubscription, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var out []model.NotificationSubscription
	for key, sub := range s.subscriptions {
		if !strings.HasPrefix(key, userID+"|") {
			continue
		}
		out = append(out, sub)
	}
	return out, nil
}

func (s *MemoryStore) UpsertSubscriptions(_ context.Context, userID string, updates []SubscriptionUpdate) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.subscriptions == nil {
		s.subscriptions = make(map[string]model.NotificationSubscription)
	}
	for _, up := range updates {
		key := subscriptionKey(userID, up.Category)
		s.subscriptions[key] = model.NotificationSubscription{
			Category: up.Category,
			Enabled:  up.Enabled,
		}
	}
	return nil
}

func subscriptionKey(userID, category string) string {
	return userID + "|" + category
}
