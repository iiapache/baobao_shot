package device

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/notification-svc/internal/model"
	"github.com/baobao/notification-svc/internal/store"
)

var (
	ErrUnauthorized   = errors.New("unauthorized")
	ErrBadRequest     = errors.New("bad request")
	ErrInvalidToken   = errors.New("invalid apns token")
	ErrDeviceNotFound = errors.New("device not found")
)

// RegisterInput is the device token registration payload.
type RegisterInput struct {
	DeviceID   string
	APNSToken  string
	AppVersion string
	OSVersion  string
	Model      string
	Region     string
}

// Service manages device token lifecycle.
type Service struct {
	store store.Store
}

// NewService creates a device registration service.
func NewService(st store.Store) *Service {
	return &Service{store: st}
}

// Register upserts an APNs token for the authenticated user.
func (s *Service) Register(ctx context.Context, userID string, in RegisterInput) (*model.DeviceToken, error) {
	if userID == "" {
		return nil, ErrUnauthorized
	}
	if err := validateRegisterInput(in); err != nil {
		return nil, err
	}

	return s.store.UpsertDeviceToken(ctx, store.UpsertDeviceTokenInput{
		UserID:     userID,
		DeviceID:   strings.TrimSpace(in.DeviceID),
		APNSToken:  strings.TrimSpace(in.APNSToken),
		Region:     strings.ToLower(strings.TrimSpace(in.Region)),
		AppVersion: strings.TrimSpace(in.AppVersion),
		OSVersion:  strings.TrimSpace(in.OSVersion),
		Model:      strings.TrimSpace(in.Model),
		UpdatedAt:  time.Now().UTC(),
	})
}

// Unregister removes a device token for the authenticated user.
func (s *Service) Unregister(ctx context.Context, userID, deviceID string) error {
	if userID == "" {
		return ErrUnauthorized
	}
	deviceID = strings.TrimSpace(deviceID)
	if deviceID == "" {
		return ErrBadRequest
	}
	if err := s.store.DeleteDeviceToken(ctx, userID, deviceID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return ErrDeviceNotFound
		}
		return err
	}
	return nil
}

// CleanupInvalidToken removes stale APNs tokens after Apple rejection.
func (s *Service) CleanupInvalidToken(ctx context.Context, apnsToken string) (int64, error) {
	apnsToken = strings.TrimSpace(apnsToken)
	if apnsToken == "" {
		return 0, ErrInvalidToken
	}
	return s.store.DeleteByAPNSToken(ctx, apnsToken)
}

func validateRegisterInput(in RegisterInput) error {
	if strings.TrimSpace(in.DeviceID) == "" ||
		strings.TrimSpace(in.APNSToken) == "" {
		return ErrBadRequest
	}
	region := strings.ToLower(strings.TrimSpace(in.Region))
	if region != "cn" && region != "os" {
		return ErrBadRequest
	}
	if len(strings.TrimSpace(in.APNSToken)) < 32 {
		return ErrInvalidToken
	}
	return nil
}
