package kafka

import "time"

const TopicIAPEvents = "iap.events"

const (
	EventIAPRefund = "iap.refund"
	EventIAPRevoke = "iap.revoke"
)

// IAPEvent is published to iap.events for credit-sub-ad-svc consumption.
type IAPEvent struct {
	EventType             string    `json:"eventType"`
	NotificationUUID      string    `json:"notificationUUID"`
	NotificationType      string    `json:"notificationType"`
	TransactionID         string    `json:"transactionId"`
	OriginalTransactionID string    `json:"originalTransactionId"`
	ProductID             string    `json:"productId"`
	SignedTransactionInfo string    `json:"signedTransactionInfo,omitempty"`
	ReceivedAt            time.Time `json:"receivedAt"`
}
