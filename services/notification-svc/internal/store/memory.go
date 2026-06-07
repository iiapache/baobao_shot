package store

import (
	"context"
	"sync"
	"time"

	"github.com/baobao/notification-svc/internal/model"
)

// MemoryStore is an in-memory Store for dev and unit tests.
type MemoryStore struct {
	mu            sync.RWMutex
	tokens        map[string]model.DeviceToken            // key: userID|deviceID
	notifications map[string]model.Notification           // key: notification id
	subscriptions map[string]model.NotificationSubscription // key: userID|category
}

// NewMemoryStore returns an empty in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		tokens:        make(map[string]model.DeviceToken),
		notifications: make(map[string]model.Notification),
		subscriptions: make(map[string]model.NotificationSubscription),
	}
}

func (s *MemoryStore) Ping(_ context.Context) error { return nil }

func deviceKey(userID, deviceID string) string {
	return userID + "|" + deviceID
}

func (s *MemoryStore) UpsertDeviceToken(_ context.Context, in UpsertDeviceTokenInput) (*model.DeviceToken, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	dt := model.DeviceToken{
		UserID:     in.UserID,
		DeviceID:   in.DeviceID,
		APNSToken:  in.APNSToken,
		Region:     in.Region,
		AppVersion: in.AppVersion,
		OSVersion:  in.OSVersion,
		Model:      in.Model,
		UpdatedAt:  in.UpdatedAt,
	}
	s.tokens[deviceKey(in.UserID, in.DeviceID)] = dt
	out := dt
	return &out, nil
}

func (s *MemoryStore) DeleteDeviceToken(_ context.Context, userID, deviceID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := deviceKey(userID, deviceID)
	if _, ok := s.tokens[key]; !ok {
		return ErrNotFound
	}
	delete(s.tokens, key)
	return nil
}

func (s *MemoryStore) DeleteByAPNSToken(_ context.Context, apnsToken string) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var n int64
	for key, dt := range s.tokens {
		if dt.APNSToken == apnsToken {
			delete(s.tokens, key)
			n++
		}
	}
	return n, nil
}

func (s *MemoryStore) ListDeviceTokensByUser(_ context.Context, userID string) ([]model.DeviceToken, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var out []model.DeviceToken
	for _, dt := range s.tokens {
		if dt.UserID == userID {
			out = append(out, dt)
		}
	}
	return out, nil
}

func (s *MemoryStore) GetDeviceToken(_ context.Context, userID, deviceID string) (*model.DeviceToken, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	dt, ok := s.tokens[deviceKey(userID, deviceID)]
	if !ok {
		return nil, ErrNotFound
	}
	out := dt
	return &out, nil
}

// seedDeviceToken is a test helper.
func (s *MemoryStore) seedDeviceToken(dt model.DeviceToken) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if dt.UpdatedAt.IsZero() {
		dt.UpdatedAt = time.Now().UTC()
	}
	s.tokens[deviceKey(dt.UserID, dt.DeviceID)] = dt
}
