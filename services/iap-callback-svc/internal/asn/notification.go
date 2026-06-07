package asn

import "time"

// Notification is a decoded Apple Server Notification v2 payload.
type Notification struct {
	NotificationType      string
	Subtype               string
	NotificationUUID      string
	SignedTransactionInfo string
	SignedRenewalInfo     string
}

// TransactionInfo is decoded from signedTransactionInfo JWS.
type TransactionInfo struct {
	TransactionID         string
	OriginalTransactionID string
	ProductID             string
	BundleID              string
	RevocationDate        time.Time
}
