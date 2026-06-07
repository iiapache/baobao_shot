package model

import "time"

// IAPReceiptStatus is the lifecycle state of a verified IAP receipt.
type IAPReceiptStatus string

const (
	IAPReceiptVerified IAPReceiptStatus = "verified"
)

// IAPReceipt stores a verified StoreKit 2 transaction.
type IAPReceipt struct {
	ID                    string
	UserID                string
	TransactionID         string
	OriginalTransactionID string
	ProductID             string
	SignedPayload         string
	VerifiedAt            time.Time
	Status                IAPReceiptStatus
}
