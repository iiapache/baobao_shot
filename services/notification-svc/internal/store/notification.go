package store

import (
	"context"
	"encoding/json"
	"time"

	"github.com/baobao/notification-svc/internal/model"
)

const (
	defaultNotificationPageSize = 50
	maxNotificationPageSize     = 50
)

// InsertNotificationInput creates a message center entry.
type InsertNotificationInput struct {
	ID        string
	UserID    string
	Category  string
	Payload   json.RawMessage
	CreatedAt time.Time
}

// ListNotificationsInput paginates notifications for a user.
type ListNotificationsInput struct {
	UserID string
	Cursor string
	Limit  int
}

// ListNotificationsResult is a cursor page of notifications.
type ListNotificationsResult struct {
	Items      []model.Notification
	NextCursor string
}

// MarkNotificationsReadInput marks notifications as read for a user.
type MarkNotificationsReadInput struct {
	UserID string
	IDs    []string
	All    bool
	ReadAt time.Time
}

// SubscriptionUpdate toggles a category for a user.
type SubscriptionUpdate struct {
	Category string
	Enabled  bool
}

// NotificationStore persists in-app notifications.
type NotificationStore interface {
	InsertNotification(ctx context.Context, in InsertNotificationInput) (*model.Notification, error)
	ListNotifications(ctx context.Context, in ListNotificationsInput) (ListNotificationsResult, error)
	CountUnreadNotifications(ctx context.Context, userID string) (int64, error)
	MarkNotificationsRead(ctx context.Context, in MarkNotificationsReadInput) (int64, error)
}

// SubscriptionStore persists per-user category toggles.
type SubscriptionStore interface {
	ListSubscriptionRows(ctx context.Context, userID string) ([]model.NotificationSubscription, error)
	UpsertSubscriptions(ctx context.Context, userID string, updates []SubscriptionUpdate) error
}
