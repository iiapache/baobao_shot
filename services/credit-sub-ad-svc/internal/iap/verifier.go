package iap

import (
	"context"
	"time"
)

// VerifiedTransaction is the trusted payload extracted from a StoreKit 2 JWS.
type VerifiedTransaction struct {
	TransactionID         string
	OriginalTransactionID string
	ProductID             string
	BundleID              string
	PurchaseDate          time.Time
	ExpiresDate           time.Time
	IsTrial               bool
	AutoRenewEnabled      bool
}

// TransactionVerifier validates signed StoreKit 2 transactions.
type TransactionVerifier interface {
	Verify(ctx context.Context, signedTransaction string) (*VerifiedTransaction, error)
}

// MockVerifier returns a fixed transaction for unit tests.
type MockVerifier struct {
	Tx  *VerifiedTransaction
	Err error
}

// Verify implements TransactionVerifier.
func (m *MockVerifier) Verify(_ context.Context, _ string) (*VerifiedTransaction, error) {
	if m.Err != nil {
		return nil, m.Err
	}
	if m.Tx == nil {
		return nil, ErrVerifyFailed
	}
	out := *m.Tx
	return &out, nil
}
