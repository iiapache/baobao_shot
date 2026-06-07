package asn

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

var ErrInvalidPayload = errors.New("invalid apple notification payload")

type outerPayload struct {
	NotificationType string `json:"notificationType"`
	Subtype          string `json:"subtype"`
	NotificationUUID string `json:"notificationUUID"`
	Data             struct {
		SignedTransactionInfo string `json:"signedTransactionInfo"`
		SignedRenewalInfo     string `json:"signedRenewalInfo"`
	} `json:"data"`
}

type transactionPayload struct {
	TransactionID         string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	ProductID             string `json:"productId"`
	BundleID              string `json:"bundleId"`
	RevocationDate        int64  `json:"revocationDate"`
}

// ParseSignedPayload decodes an Apple Server Notifications v2 signedPayload JWS.
func ParseSignedPayload(signedPayload string) (*Notification, error) {
	signedPayload = strings.TrimSpace(signedPayload)
	if signedPayload == "" {
		return nil, ErrInvalidPayload
	}
	if strings.HasPrefix(signedPayload, "mock-asn:") {
		return parseMockASN(signedPayload)
	}

	raw, err := decodeJWSPayload(signedPayload)
	if err != nil {
		return nil, err
	}
	var payload outerPayload
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nil, errors.Join(ErrInvalidPayload, err)
	}
	if payload.NotificationType == "" || payload.NotificationUUID == "" {
		return nil, ErrInvalidPayload
	}
	return &Notification{
		NotificationType:      payload.NotificationType,
		Subtype:               payload.Subtype,
		NotificationUUID:      payload.NotificationUUID,
		SignedTransactionInfo: payload.Data.SignedTransactionInfo,
		SignedRenewalInfo:     payload.Data.SignedRenewalInfo,
	}, nil
}

// ParseTransactionInfo decodes signedTransactionInfo from an ASN notification.
func ParseTransactionInfo(signedTransactionInfo string, allowedBundleIDs map[string]struct{}) (*TransactionInfo, error) {
	signedTransactionInfo = strings.TrimSpace(signedTransactionInfo)
	if signedTransactionInfo == "" {
		return nil, ErrInvalidPayload
	}
	if strings.HasPrefix(signedTransactionInfo, "mock:") {
		return parseMockTransaction(signedTransactionInfo)
	}

	raw, err := decodeJWSPayload(signedTransactionInfo)
	if err != nil {
		return nil, err
	}
	var payload transactionPayload
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nil, errors.Join(ErrInvalidPayload, err)
	}
	if payload.TransactionID == "" || payload.ProductID == "" {
		return nil, ErrInvalidPayload
	}
	if payload.OriginalTransactionID == "" {
		payload.OriginalTransactionID = payload.TransactionID
	}
	if len(allowedBundleIDs) > 0 {
		if _, ok := allowedBundleIDs[payload.BundleID]; !ok {
			return nil, ErrInvalidPayload
		}
	}
	return &TransactionInfo{
		TransactionID:         payload.TransactionID,
		OriginalTransactionID: payload.OriginalTransactionID,
		ProductID:             payload.ProductID,
		BundleID:              payload.BundleID,
		RevocationDate:        millisToTime(payload.RevocationDate),
	}, nil
}

// parseMockASN format: mock-asn:{type}:{uuid}:{signedTransactionInfo}
func parseMockASN(raw string) (*Notification, error) {
	parts := strings.SplitN(strings.TrimPrefix(raw, "mock-asn:"), ":", 3)
	if len(parts) < 3 {
		return nil, ErrInvalidPayload
	}
	notificationType := strings.TrimSpace(parts[0])
	notificationUUID := strings.TrimSpace(parts[1])
	signedTransactionInfo := strings.TrimSpace(parts[2])
	if notificationType == "" || notificationUUID == "" || signedTransactionInfo == "" {
		return nil, ErrInvalidPayload
	}
	return &Notification{
		NotificationType:      notificationType,
		NotificationUUID:      notificationUUID,
		SignedTransactionInfo: signedTransactionInfo,
	}, nil
}

// parseMockTransaction format: mock:{transactionId}:{productId}[:originalTransactionId[:bundleId]]
func parseMockTransaction(raw string) (*TransactionInfo, error) {
	parts := strings.Split(strings.TrimPrefix(raw, "mock:"), ":")
	if len(parts) < 2 {
		return nil, ErrInvalidPayload
	}
	tx := strings.TrimSpace(parts[0])
	productID := strings.TrimSpace(parts[1])
	if tx == "" || productID == "" {
		return nil, ErrInvalidPayload
	}
	originalTx := tx
	if len(parts) >= 3 && strings.TrimSpace(parts[2]) != "" {
		originalTx = strings.TrimSpace(parts[2])
	}
	bundleID := ""
	if len(parts) >= 4 {
		bundleID = strings.TrimSpace(parts[3])
	}
	return &TransactionInfo{
		TransactionID:         tx,
		OriginalTransactionID: originalTx,
		ProductID:             productID,
		BundleID:              bundleID,
	}, nil
}

func decodeJWSPayload(token string) ([]byte, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, ErrInvalidPayload
	}
	if strings.TrimSpace(parts[0]) == "" || strings.TrimSpace(parts[2]) == "" {
		return nil, ErrInvalidPayload
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, errors.Join(ErrInvalidPayload, err)
	}
	return raw, nil
}

func millisToTime(ms int64) time.Time {
	if ms <= 0 {
		return time.Time{}
	}
	return time.UnixMilli(ms).UTC()
}
