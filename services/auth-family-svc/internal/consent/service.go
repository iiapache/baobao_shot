package consent

import (
	"context"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

// Service manages child-data consent recording and validation.
type Service struct {
	store store.ConsentStore
	now   func() time.Time
}

// NewService creates a consent service.
func NewService(st store.ConsentStore) *Service {
	return &Service{store: st, now: time.Now}
}

// RecordChildDataConsent persists consent when the user accepts the current version.
func (s *Service) RecordChildDataConsent(ctx context.Context, userID, version string, accepted bool, ip, deviceID string) (*model.ChildConsent, error) {
	version = strings.TrimSpace(version)
	if version == "" {
		return nil, ErrVersionMismatch
	}
	if version != CurrentConsentVersion {
		return nil, ErrVersionMismatch
	}
	if !accepted {
		return nil, ErrNotAccepted
	}

	now := s.now().UTC()
	return s.store.RecordChildConsent(ctx, store.RecordChildConsentInput{
		UserID:   userID,
		Version:  version,
		AgreedAt: now,
		IP:       ip,
		DeviceID: deviceID,
	})
}

// HasValidChildDataConsent reports whether the user agreed to the current consent version.
func (s *Service) HasValidChildDataConsent(ctx context.Context, userID string) (bool, error) {
	return s.store.HasChildConsent(ctx, userID, CurrentConsentVersion)
}
