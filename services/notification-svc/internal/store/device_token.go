package store

import (
	"context"
	"time"

	"github.com/baobao/notification-svc/internal/model"
)

// UpsertDeviceTokenInput registers or updates a device token.
type UpsertDeviceTokenInput struct {
	UserID     string
	DeviceID   string
	APNSToken  string
	Region     string
	AppVersion string
	OSVersion  string
	Model      string
	UpdatedAt  time.Time
}

// DeviceTokenStore persists APNs device registrations.
type DeviceTokenStore interface {
	UpsertDeviceToken(ctx context.Context, in UpsertDeviceTokenInput) (*model.DeviceToken, error)
	DeleteDeviceToken(ctx context.Context, userID, deviceID string) error
	DeleteByAPNSToken(ctx context.Context, apnsToken string) (int64, error)
	ListDeviceTokensByUser(ctx context.Context, userID string) ([]model.DeviceToken, error)
	GetDeviceToken(ctx context.Context, userID, deviceID string) (*model.DeviceToken, error)
}

// Store is the persistence boundary for notification-svc.
type Store interface {
	DeviceTokenStore
	NotificationStore
	SubscriptionStore
	Ping(ctx context.Context) error
}
