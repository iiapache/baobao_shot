package store

import (
	"context"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// IAPReceiptStore persists verified IAP transactions.
type IAPReceiptStore interface {
	GetIAPReceiptByTransactionID(ctx context.Context, transactionID string) (*model.IAPReceipt, error)
	CreateIAPReceipt(ctx context.Context, receipt model.IAPReceipt) error
}
