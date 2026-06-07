package processor

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/iap-callback-svc/internal/asn"
	"github.com/baobao/iap-callback-svc/internal/idempotency"
	"github.com/baobao/iap-callback-svc/internal/kafka"
)

var (
	ErrInvalidRequest = errors.New("invalid notification request")
	ErrDuplicate      = errors.New("duplicate notification")
)

// Result summarizes a processed Apple notification.
type Result struct {
	NotificationUUID string
	NotificationType string
	EventType        string
	TransactionID    string
	Duplicate        bool
	Published        bool
}

// Service parses Apple ASN v2 payloads and publishes iap.events.
type Service struct {
	idempotency idempotency.Store
	producer    kafka.Producer
	topic       string
	allowedBundleIDs map[string]struct{}
	now         func() time.Time
}

// NewService creates an ASN processor.
func NewService(idempotencyStore idempotency.Store, producer kafka.Producer, topic string, bundleIDs ...string) *Service {
	allowed := make(map[string]struct{}, len(bundleIDs))
	for _, id := range bundleIDs {
		id = strings.TrimSpace(id)
		if id != "" {
			allowed[id] = struct{}{}
		}
	}
	if topic == "" {
		topic = kafka.TopicIAPEvents
	}
	return &Service{
		idempotency:      idempotencyStore,
		producer:         producer,
		topic:            topic,
		allowedBundleIDs: allowed,
		now:              time.Now,
	}
}

// Handle processes one signedPayload from Apple Server Notifications v2.
func (s *Service) Handle(ctx context.Context, signedPayload string) (Result, error) {
	signedPayload = strings.TrimSpace(signedPayload)
	if signedPayload == "" {
		return Result{}, ErrInvalidRequest
	}

	notification, err := asn.ParseSignedPayload(signedPayload)
	if err != nil {
		return Result{}, ErrInvalidRequest
	}

	claimed, err := s.idempotency.TryClaim(ctx, notification.NotificationUUID)
	if err != nil {
		return Result{}, err
	}
	if !claimed {
		return Result{
			NotificationUUID: notification.NotificationUUID,
			NotificationType: notification.NotificationType,
			Duplicate:        true,
		}, ErrDuplicate
	}

	txInfo, err := asn.ParseTransactionInfo(notification.SignedTransactionInfo, s.allowedBundleIDs)
	if err != nil {
		return Result{}, ErrInvalidRequest
	}

	eventType, ok := eventTypeForNotification(notification.NotificationType)
	if !ok {
		return Result{
			NotificationUUID: notification.NotificationUUID,
			NotificationType: notification.NotificationType,
			TransactionID:    txInfo.TransactionID,
		}, nil
	}

	evt := kafka.IAPEvent{
		EventType:             eventType,
		NotificationUUID:      notification.NotificationUUID,
		NotificationType:      notification.NotificationType,
		TransactionID:         txInfo.TransactionID,
		OriginalTransactionID: txInfo.OriginalTransactionID,
		ProductID:             txInfo.ProductID,
		SignedTransactionInfo: notification.SignedTransactionInfo,
		ReceivedAt:            s.now().UTC(),
	}
	if s.producer != nil {
		if err := s.producer.Publish(ctx, s.topic, evt); err != nil {
			return Result{}, err
		}
	}

	return Result{
		NotificationUUID: notification.NotificationUUID,
		NotificationType: notification.NotificationType,
		EventType:        eventType,
		TransactionID:    txInfo.TransactionID,
		Published:        s.producer != nil,
	}, nil
}

func eventTypeForNotification(notificationType string) (string, bool) {
	switch strings.ToUpper(strings.TrimSpace(notificationType)) {
	case "REFUND":
		return kafka.EventIAPRefund, true
	case "REVOKE":
		return kafka.EventIAPRevoke, true
	default:
		return "", false
	}
}
