package store

import (
	"context"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *MemoryStore) GetIAPReceiptByTransactionID(_ context.Context, transactionID string) (*model.IAPReceipt, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	receiptID, ok := s.iapByTransactionID[transactionID]
	if !ok {
		return nil, ErrNotFound
	}
	receipt, ok := s.iapReceipts[receiptID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneIAPReceipt(receipt), nil
}

func (s *MemoryStore) CreateIAPReceipt(_ context.Context, receipt model.IAPReceipt) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.iapByTransactionID[receipt.TransactionID]; exists {
		return ErrDuplicateTransaction
	}
	cloned := cloneIAPReceipt(&receipt)
	s.iapReceipts[receipt.ID] = cloned
	s.iapByTransactionID[receipt.TransactionID] = receipt.ID
	return nil
}

func cloneIAPReceipt(receipt *model.IAPReceipt) *model.IAPReceipt {
	if receipt == nil {
		return nil
	}
	out := *receipt
	return &out
}
