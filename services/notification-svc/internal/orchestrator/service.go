package orchestrator

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/inbox"
	"github.com/baobao/notification-svc/internal/model"
	"github.com/baobao/notification-svc/internal/store"
)

var (
	ErrBadRequest = errors.New("bad request")
)

// DispatchInput describes a push to deliver after category routing.
type DispatchInput struct {
	UserID     string
	Category   string
	Title      string
	Body       string
	Payload    json.RawMessage
	CustomData map[string]string
	SilentPush bool
}

// DispatchResult summarizes inbox + APNs delivery.
type DispatchResult struct {
	InboxCreated bool
	PushAttempts int
}

// Service routes Kafka events to inbox entries and APNs pushes (T5.9).
type Service struct {
	store store.Store
	inbox *inbox.Service
	apns  *apns.Client
	topic string
}

// NewService creates a push orchestrator.
func NewService(st store.Store, inboxSvc *inbox.Service, apnsClient *apns.Client, apnsTopic string) *Service {
	return &Service{
		store: st,
		inbox: inboxSvc,
		apns:  apnsClient,
		topic: strings.TrimSpace(apnsTopic),
	}
}

// Dispatch writes the message center entry and sends APNs when the category is subscribed.
func (s *Service) Dispatch(ctx context.Context, in DispatchInput) (DispatchResult, error) {
	if s == nil {
		return DispatchResult{}, fmt.Errorf("orchestrator not initialized")
	}
	userID := strings.TrimSpace(in.UserID)
	if userID == "" {
		return DispatchResult{}, ErrBadRequest
	}
	category := strings.TrimSpace(in.Category)
	if !model.ValidCategory(category) {
		return DispatchResult{}, ErrBadRequest
	}

	result := DispatchResult{}
	if s.inbox != nil {
		if _, err := s.inbox.Create(ctx, inbox.CreateInput{
			UserID:   userID,
			Category: category,
			Payload:  in.Payload,
		}); err != nil {
			return result, err
		}
		result.InboxCreated = true
	}

	enabled, err := s.isPushEnabled(ctx, userID, category)
	if err != nil {
		return result, err
	}
	if !enabled || s.apns == nil {
		return result, nil
	}

	tokens, err := s.store.ListDeviceTokensByUser(ctx, userID)
	if err != nil {
		return result, err
	}
	if len(tokens) == 0 {
		return result, nil
	}

	priority := PushPriority(category)
	custom := cloneCustomData(in.CustomData)
	if custom == nil {
		custom = make(map[string]string)
	}
	custom["category"] = category

	for _, dt := range tokens {
		region := apns.Region(strings.ToLower(dt.Region))
		if in.SilentPush {
			_, _ = s.apns.Send(ctx, region, apns.PushPayload{
				DeviceToken: dt.APNSToken,
				Priority:    priority,
				Silent:      true,
				Topic:       s.topic,
				Category:    category,
				CustomData:  custom,
			})
			result.PushAttempts++
		}

		if strings.TrimSpace(in.Title) != "" || strings.TrimSpace(in.Body) != "" {
			_, _ = s.apns.Send(ctx, region, apns.PushPayload{
				DeviceToken: dt.APNSToken,
				Title:       in.Title,
				Body:        in.Body,
				Priority:    priority,
				Topic:       s.topic,
				Category:    category,
				CustomData:  custom,
			})
			result.PushAttempts++
		}
	}

	return result, nil
}

func (s *Service) isPushEnabled(ctx context.Context, userID, category string) (bool, error) {
	rows, err := s.store.ListSubscriptionRows(ctx, userID)
	if err != nil {
		return false, err
	}
	for _, row := range rows {
		if row.Category == category {
			return row.Enabled, nil
		}
	}
	return model.DefaultSubscriptionEnabled(category), nil
}

func cloneCustomData(src map[string]string) map[string]string {
	if len(src) == 0 {
		return nil
	}
	out := make(map[string]string, len(src))
	for k, v := range src {
		out[k] = v
	}
	return out
}
