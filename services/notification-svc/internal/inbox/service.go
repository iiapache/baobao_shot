package inbox

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/baobao/notification-svc/internal/model"
	"github.com/baobao/notification-svc/internal/store"
	"github.com/google/uuid"
)

var (
	ErrUnauthorized   = errors.New("unauthorized")
	ErrBadRequest     = errors.New("bad request")
	ErrInvalidCursor  = errors.New("invalid cursor")
	ErrInvalidCategory = errors.New("invalid category")
)

// ListInput paginates the message center for a user.
type ListInput struct {
	UserID string
	Cursor string
	Limit  int
}

// ListResult is a notifications page with unread count.
type ListResult struct {
	Items       []model.Notification `json:"items"`
	UnreadCount int64                `json:"unreadCount"`
	NextCursor  *string              `json:"nextCursor,omitempty"`
}

// MarkReadInput marks notifications as read.
type MarkReadInput struct {
	UserID string
	IDs    []string
	All    bool
}

// MarkReadResult reports how many entries were marked read.
type MarkReadResult struct {
	MarkedCount int64 `json:"markedCount"`
	UnreadCount int64 `json:"unreadCount"`
}

// SubscriptionPatchItem updates one category toggle.
type SubscriptionPatchItem struct {
	Category string `json:"category"`
	Enabled  bool   `json:"enabled"`
}

// SubscriptionsResult is the full category subscription state.
type SubscriptionsResult struct {
	Subscriptions []model.NotificationSubscription `json:"subscriptions"`
}

// CreateInput inserts a notification (used by tests and future Kafka consumer).
type CreateInput struct {
	UserID   string
	Category string
	Payload  json.RawMessage
}

// Service implements message center business logic.
type Service struct {
	store store.Store
}

// NewService creates an inbox service.
func NewService(st store.Store) *Service {
	return &Service{store: st}
}

// List returns paginated notifications and the current unread count.
func (s *Service) List(ctx context.Context, in ListInput) (ListResult, error) {
	if in.UserID == "" {
		return ListResult{}, ErrUnauthorized
	}

	page, err := s.store.ListNotifications(ctx, store.ListNotificationsInput{
		UserID: in.UserID,
		Cursor: strings.TrimSpace(in.Cursor),
		Limit:  in.Limit,
	})
	if err != nil {
		if errors.Is(err, store.ErrInvalidCursor) {
			return ListResult{}, ErrInvalidCursor
		}
		return ListResult{}, err
	}

	unread, err := s.store.CountUnreadNotifications(ctx, in.UserID)
	if err != nil {
		return ListResult{}, err
	}

	result := ListResult{
		Items:       page.Items,
		UnreadCount: unread,
	}
	if page.NextCursor != "" {
		cursor := page.NextCursor
		result.NextCursor = &cursor
	}
	return result, nil
}

// MarkRead marks notifications as read and returns updated unread count.
func (s *Service) MarkRead(ctx context.Context, in MarkReadInput) (MarkReadResult, error) {
	if in.UserID == "" {
		return MarkReadResult{}, ErrUnauthorized
	}

	marked, err := s.store.MarkNotificationsRead(ctx, store.MarkNotificationsReadInput{
		UserID: in.UserID,
		IDs:    in.IDs,
		All:    in.All,
		ReadAt: time.Now().UTC(),
	})
	if err != nil {
		return MarkReadResult{}, err
	}

	unread, err := s.store.CountUnreadNotifications(ctx, in.UserID)
	if err != nil {
		return MarkReadResult{}, err
	}

	return MarkReadResult{MarkedCount: marked, UnreadCount: unread}, nil
}

// GetSubscriptions returns merged category toggles with defaults.
func (s *Service) GetSubscriptions(ctx context.Context, userID string) (SubscriptionsResult, error) {
	if userID == "" {
		return SubscriptionsResult{}, ErrUnauthorized
	}
	subs, err := s.mergeSubscriptions(ctx, userID)
	if err != nil {
		return SubscriptionsResult{}, err
	}
	return SubscriptionsResult{Subscriptions: subs}, nil
}

// UpdateSubscriptions patches category toggles and returns merged state.
func (s *Service) UpdateSubscriptions(ctx context.Context, userID string, updates []SubscriptionPatchItem) (SubscriptionsResult, error) {
	if userID == "" {
		return SubscriptionsResult{}, ErrUnauthorized
	}
	if len(updates) == 0 {
		return SubscriptionsResult{}, ErrBadRequest
	}

	storeUpdates := make([]store.SubscriptionUpdate, 0, len(updates))
	for _, up := range updates {
		category := strings.TrimSpace(up.Category)
		if !model.ValidCategory(category) {
			return SubscriptionsResult{}, ErrInvalidCategory
		}
		storeUpdates = append(storeUpdates, store.SubscriptionUpdate{
			Category: category,
			Enabled:  up.Enabled,
		})
	}

	if err := s.store.UpsertSubscriptions(ctx, userID, storeUpdates); err != nil {
		return SubscriptionsResult{}, err
	}

	subs, err := s.mergeSubscriptions(ctx, userID)
	if err != nil {
		return SubscriptionsResult{}, err
	}
	return SubscriptionsResult{Subscriptions: subs}, nil
}

// Create inserts a notification entry.
func (s *Service) Create(ctx context.Context, in CreateInput) (*model.Notification, error) {
	if in.UserID == "" {
		return nil, ErrUnauthorized
	}
	category := strings.TrimSpace(in.Category)
	if !model.ValidCategory(category) {
		return nil, ErrInvalidCategory
	}

	return s.store.InsertNotification(ctx, store.InsertNotificationInput{
		ID:        "ntf_" + uuid.NewString(),
		UserID:    in.UserID,
		Category:  category,
		Payload:   in.Payload,
		CreatedAt: time.Now().UTC(),
	})
}

func (s *Service) mergeSubscriptions(ctx context.Context, userID string) ([]model.NotificationSubscription, error) {
	rows, err := s.store.ListSubscriptionRows(ctx, userID)
	if err != nil {
		return nil, err
	}

	enabledByCategory := make(map[string]bool, len(rows))
	for _, row := range rows {
		enabledByCategory[row.Category] = row.Enabled
	}

	out := make([]model.NotificationSubscription, 0, len(model.AllCategories))
	for _, category := range model.AllCategories {
		enabled, ok := enabledByCategory[category]
		if !ok {
			enabled = model.DefaultSubscriptionEnabled(category)
		}
		out = append(out, model.NotificationSubscription{
			Category: category,
			Enabled:  enabled,
		})
	}
	return out, nil
}
