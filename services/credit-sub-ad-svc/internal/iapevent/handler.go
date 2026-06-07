package iapevent

import (
	"context"
	"errors"
	"strings"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/baobao/credit-sub-ad-svc/internal/subscription"
)

const (
	ledgerGrantRefKind  = "iap"
	refundLedgerRefKind = "iap_refund"
	revokeLedgerRefKind = "iap_revoke"
)

// IAPEvent is a Kafka iap.events payload from iap-callback-svc.
type IAPEvent struct {
	EventType             string `json:"eventType"`
	NotificationUUID      string `json:"notificationUUID"`
	NotificationType      string `json:"notificationType"`
	TransactionID         string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	ProductID             string `json:"productId"`
}

const (
	EventIAPRefund = "iap.refund"
	EventIAPRevoke = "iap.revoke"
)

// Handler applies REFUND/REVOKE side effects on the credit ledger and subscriptions.
type Handler struct {
	store        store.Store
	credits      *credit.Service
	subscription *subscription.Service
	catalog      iap.ProductCatalog
	subCatalog   subscription.ProductCatalog
}

// NewHandler creates an IAP Kafka event handler.
func NewHandler(
	st store.Store,
	credits *credit.Service,
	subSvc *subscription.Service,
	catalog iap.ProductCatalog,
	subCatalog subscription.ProductCatalog,
) *Handler {
	if catalog == nil {
		catalog = iap.DefaultProductCatalog
	}
	if subCatalog == nil {
		subCatalog = subscription.DefaultProductCatalog
	}
	return &Handler{
		store:        st,
		credits:      credits,
		subscription: subSvc,
		catalog:      catalog,
		subCatalog:   subCatalog,
	}
}

// Handle processes one iap.events Kafka message.
func (h *Handler) Handle(ctx context.Context, evt IAPEvent) error {
	switch strings.TrimSpace(evt.EventType) {
	case EventIAPRefund:
		return h.handleRefund(ctx, evt)
	case EventIAPRevoke:
		return h.handleRevoke(ctx, evt)
	default:
		return nil
	}
}

func (h *Handler) handleRefund(ctx context.Context, evt IAPEvent) error {
	if err := h.clawbackCredits(ctx, evt, refundLedgerRefKind); err != nil {
		return err
	}
	return h.revokeSubscriptionIfNeeded(ctx, evt)
}

func (h *Handler) handleRevoke(ctx context.Context, evt IAPEvent) error {
	if err := h.clawbackCredits(ctx, evt, revokeLedgerRefKind); err != nil {
		return err
	}
	return h.revokeSubscriptionIfNeeded(ctx, evt)
}

func (h *Handler) clawbackCredits(ctx context.Context, evt IAPEvent, refKind string) error {
	transactionID := strings.TrimSpace(evt.TransactionID)
	if transactionID == "" {
		return iap.ErrInvalidRequest
	}

	if _, err := h.store.GetLedgerByRef(ctx, refKind, transactionID); err == nil {
		return nil
	} else if !errors.Is(err, store.ErrNotFound) {
		return err
	}

	receipt, err := h.store.GetIAPReceiptByTransactionID(ctx, transactionID)
	if errors.Is(err, store.ErrNotFound) {
		return nil
	}
	if err != nil {
		return err
	}

	amount, ok := h.grantAmount(ctx, receipt.TransactionID, receipt.ProductID)
	if !ok || amount <= 0 {
		return nil
	}

	_, err = h.credits.Clawback(ctx, receipt.UserID, amount, refKind, transactionID)
	return err
}

func (h *Handler) grantAmount(ctx context.Context, transactionID, productID string) (int64, bool) {
	entry, err := h.store.GetLedgerByRef(ctx, ledgerGrantRefKind, transactionID)
	if err == nil && entry.Amount > 0 {
		return entry.Amount, true
	}
	return h.catalog.CreditsForProduct(productID)
}

func (h *Handler) revokeSubscriptionIfNeeded(ctx context.Context, evt IAPEvent) error {
	if h.subscription == nil {
		return nil
	}
	productID := strings.TrimSpace(evt.ProductID)
	if productID == "" {
		return nil
	}
	if _, ok := h.subCatalog.ProductForID(productID); !ok {
		return nil
	}

	originalTx := strings.TrimSpace(evt.OriginalTransactionID)
	if originalTx == "" {
		originalTx = strings.TrimSpace(evt.TransactionID)
	}
	if originalTx == "" {
		return nil
	}

	_, err := h.subscription.ApplyEvent(ctx, originalTx, subscription.EventRefund)
	if errors.Is(err, store.ErrNotFound) || errors.Is(err, subscription.ErrInvalidTransition) {
		return nil
	}
	return err
}
