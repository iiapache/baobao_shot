package iap

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/google/uuid"
)

const ledgerRefKind = "iap"

// VerifyRequest is the service input for IAP credit verification.
type VerifyRequest struct {
	UserID            string
	TransactionID     string
	SignedTransaction string
	ProductID         string
}

// VerifyResult is returned after IAP verification and optional credit grant.
type VerifyResult struct {
	GrantedCredits int64
	BalanceAfter   int64
	TransactionID  string
	LedgerID       string
	Duplicate      bool
}

// Service verifies StoreKit 2 transactions and grants credits idempotently.
type Service struct {
	store    store.Store
	credits  *credit.Service
	verifier TransactionVerifier
	catalog  ProductCatalog
	now      func() time.Time
	newID    func() string
}

// NewService creates an IAP verification service.
func NewService(st store.Store, credits *credit.Service, verifier TransactionVerifier, catalog ProductCatalog) *Service {
	if catalog == nil {
		catalog = DefaultProductCatalog
	}
	if verifier == nil {
		verifier = NewJWSVerifier()
	}
	return &Service{
		store:    st,
		credits:  credits,
		verifier: verifier,
		catalog:  catalog,
		now:      time.Now,
		newID:    func() string { return "iap_" + uuid.NewString()[:12] },
	}
}

// Verify validates a signed transaction and grants credits once per transactionId.
func (s *Service) Verify(ctx context.Context, req VerifyRequest) (VerifyResult, error) {
	if err := validateVerifyRequest(req); err != nil {
		return VerifyResult{}, err
	}

	existing, err := s.store.GetIAPReceiptByTransactionID(ctx, req.TransactionID)
	if err == nil {
		if existing.UserID != req.UserID {
			return VerifyResult{}, ErrUserMismatch
		}
		return s.duplicateResult(ctx, existing, req.ProductID)
	}
	if !errors.Is(err, store.ErrNotFound) {
		return VerifyResult{}, err
	}

	verified, err := s.verifier.Verify(ctx, req.SignedTransaction)
	if err != nil {
		return VerifyResult{}, ErrVerifyFailed
	}
	if verified.TransactionID != req.TransactionID {
		return VerifyResult{}, ErrTransactionMismatch
	}
	if verified.ProductID != req.ProductID {
		return VerifyResult{}, ErrProductMismatch
	}

	credits, ok := s.catalog.CreditsForProduct(req.ProductID)
	if !ok {
		return VerifyResult{}, ErrProductUnknown
	}

	grant, err := s.credits.Grant(ctx, req.UserID, credits, ledgerRefKind, req.TransactionID)
	if err != nil {
		return VerifyResult{}, err
	}

	receipt := model.IAPReceipt{
		ID:                    s.newID(),
		UserID:                req.UserID,
		TransactionID:         req.TransactionID,
		OriginalTransactionID: verified.OriginalTransactionID,
		ProductID:             req.ProductID,
		SignedPayload:         req.SignedTransaction,
		VerifiedAt:            s.now().UTC(),
		Status:                model.IAPReceiptVerified,
	}
	if err := s.store.CreateIAPReceipt(ctx, receipt); err != nil {
		if errors.Is(err, store.ErrDuplicateTransaction) {
			existing, fetchErr := s.store.GetIAPReceiptByTransactionID(ctx, req.TransactionID)
			if fetchErr != nil {
				return VerifyResult{}, fetchErr
			}
			if existing.UserID != req.UserID {
				return VerifyResult{}, ErrUserMismatch
			}
			return s.duplicateResult(ctx, existing, req.ProductID)
		}
		return VerifyResult{}, err
	}

	granted := credits
	if grant.Duplicate {
		granted = 0
	}
	return VerifyResult{
		GrantedCredits: granted,
		BalanceAfter:   grant.Entry.BalanceAfter,
		TransactionID:  req.TransactionID,
		LedgerID:       grant.Entry.ID,
		Duplicate:      grant.Duplicate,
	}, nil
}

func (s *Service) duplicateResult(ctx context.Context, existing *model.IAPReceipt, productID string) (VerifyResult, error) {
	if existing.ProductID != productID {
		return VerifyResult{}, ErrProductMismatch
	}

	entry, err := s.store.GetLedgerByRef(ctx, ledgerRefKind, existing.TransactionID)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		return VerifyResult{}, err
	}

	balanceAfter := int64(0)
	ledgerID := ""
	if entry != nil {
		balanceAfter = entry.BalanceAfter
		ledgerID = entry.ID
	} else {
		bal, balErr := s.credits.GetBalance(ctx, existing.UserID)
		if balErr != nil {
			return VerifyResult{}, balErr
		}
		balanceAfter = bal.Balance
	}

	return VerifyResult{
		GrantedCredits: 0,
		BalanceAfter:   balanceAfter,
		TransactionID:  existing.TransactionID,
		LedgerID:       ledgerID,
		Duplicate:      true,
	}, nil
}

func validateVerifyRequest(req VerifyRequest) error {
	if strings.TrimSpace(req.UserID) == "" ||
		strings.TrimSpace(req.TransactionID) == "" ||
		strings.TrimSpace(req.SignedTransaction) == "" ||
		strings.TrimSpace(req.ProductID) == "" {
		return ErrInvalidRequest
	}
	return nil
}
