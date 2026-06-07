package subscription

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/google/uuid"
)

const entitlementCacheTTL = 10 * time.Minute

// VerifyRequest is the service input for subscription IAP verification.
type VerifyRequest struct {
	UserID            string
	TransactionID     string
	SignedTransaction string
	ProductID         string
}

// VerifyResult is returned after subscription IAP verification.
type VerifyResult struct {
	SubscriptionID string
	State          model.SubscriptionState
	SKU            string
	PeriodStart    time.Time
	PeriodEnd      time.Time
	AutoRenew      bool
	Entitlements   model.Entitlements
	Duplicate      bool
}

// MeResult is the current subscription status for a user.
type MeResult struct {
	Active           bool
	State            string
	SKU              string
	PeriodStart      *time.Time
	PeriodEnd        *time.Time
	AutoRenew        bool
	CacheTTLSeconds  int
	Entitlements     model.Entitlements
	SubscriptionID   string
}

// Service manages subscription lifecycle and entitlements.
type Service struct {
	store    store.Store
	verifier iap.TransactionVerifier
	catalog  ProductCatalog
	now      func() time.Time
	newID    func() string
	grace    time.Duration
}

// NewService creates a subscription service.
func NewService(st store.Store, verifier iap.TransactionVerifier, catalog ProductCatalog) *Service {
	if catalog == nil {
		catalog = DefaultProductCatalog
	}
	if verifier == nil {
		verifier = iap.NewJWSVerifier()
	}
	return &Service{
		store:    st,
		verifier: verifier,
		catalog:  catalog,
		now:      time.Now,
		newID:    func() string { return "sub_" + uuid.NewString()[:12] },
		grace:    DefaultGracePeriod,
	}
}

// Verify validates a signed subscription transaction and updates lifecycle state.
func (s *Service) Verify(ctx context.Context, req VerifyRequest) (VerifyResult, error) {
	if err := validateVerifyRequest(req); err != nil {
		return VerifyResult{}, err
	}

	existingReceipt, receiptErr := s.store.GetIAPReceiptByTransactionID(ctx, req.TransactionID)
	if receiptErr == nil {
		if existingReceipt.UserID != req.UserID {
			return VerifyResult{}, ErrUserMismatch
		}
		return s.duplicateVerifyResult(ctx, existingReceipt)
	}
	if !errors.Is(receiptErr, store.ErrNotFound) {
		return VerifyResult{}, receiptErr
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
	if _, ok := s.catalog.ProductForID(req.ProductID); !ok {
		return VerifyResult{}, ErrProductUnknown
	}

	periodStart, periodEnd := resolvePeriod(verified, s.catalog, s.now())
	autoRenew := verified.AutoRenewEnabled

	existing, err := s.store.GetSubscriptionByOriginalTransactionID(ctx, verified.OriginalTransactionID)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		return VerifyResult{}, err
	}

	now := s.now().UTC()
	var sub model.Subscription
	if existing == nil {
		state := InitialStateForPurchase(verified.IsTrial)
		sub = model.Subscription{
			ID:                    s.newID(),
			UserID:                req.UserID,
			OriginalTransactionID: verified.OriginalTransactionID,
			SKU:                   req.ProductID,
			PeriodStart:           periodStart,
			PeriodEnd:             periodEnd,
			State:                 state,
			AutoRenew:             autoRenew,
			LastEventAt:           now,
		}
		if err := s.store.CreateSubscription(ctx, sub); err != nil {
			return VerifyResult{}, err
		}
	} else {
		if existing.UserID != req.UserID {
			return VerifyResult{}, ErrUserMismatch
		}
		if existing.SKU != req.ProductID {
			return VerifyResult{}, ErrProductMismatch
		}

		event := EventRenew
		if existing.State == model.SubscriptionExpired {
			event = EventRepurchase
		}
		nextState, err := NextState(existing.State, event)
		if err != nil {
			return VerifyResult{}, err
		}

		sub = *existing
		sub.State = nextState
		sub.PeriodStart = periodStart
		sub.PeriodEnd = periodEnd
		sub.AutoRenew = autoRenew
		sub.LastEventAt = now
		if err := s.store.UpdateSubscription(ctx, sub); err != nil {
			return VerifyResult{}, err
		}
	}

	receipt := model.IAPReceipt{
		ID:                    "subrcpt_" + uuid.NewString()[:12],
		UserID:                req.UserID,
		TransactionID:         req.TransactionID,
		OriginalTransactionID: verified.OriginalTransactionID,
		ProductID:             req.ProductID,
		SignedPayload:         req.SignedTransaction,
		VerifiedAt:            now,
		Status:                model.IAPReceiptVerified,
	}
	if err := s.store.CreateIAPReceipt(ctx, receipt); err != nil {
		if errors.Is(err, store.ErrDuplicateTransaction) {
			return s.duplicateVerifyResult(ctx, &receipt)
		}
		return VerifyResult{}, err
	}

	return verifyResultFromSubscription(sub, false), nil
}

// GetMe returns the latest subscription status and entitlements for a user.
func (s *Service) GetMe(ctx context.Context, userID string) (MeResult, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return MeResult{}, ErrInvalidRequest
	}

	sub, err := s.store.GetLatestSubscriptionByUserID(ctx, userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return MeResult{
				Active:          false,
				State:           "none",
				CacheTTLSeconds: int(entitlementCacheTTL.Seconds()),
				Entitlements:    model.Entitlements{},
			}, nil
		}
		return MeResult{}, err
	}

	active := model.IsEntitled(sub.State)
	return MeResult{
		Active:          active,
		State:           string(sub.State),
		SKU:             sub.SKU,
		PeriodStart:     &sub.PeriodStart,
		PeriodEnd:       &sub.PeriodEnd,
		AutoRenew:       sub.AutoRenew,
		CacheTTLSeconds: int(entitlementCacheTTL.Seconds()),
		Entitlements:    model.EntitlementsForState(sub.State),
		SubscriptionID:  sub.ID,
	}, nil
}

// ApplyEvent applies a lifecycle event to a subscription by original transaction id.
func (s *Service) ApplyEvent(ctx context.Context, originalTransactionID string, event EventType) (*model.Subscription, error) {
	originalTransactionID = strings.TrimSpace(originalTransactionID)
	if originalTransactionID == "" {
		return nil, ErrInvalidRequest
	}

	sub, err := s.store.GetSubscriptionByOriginalTransactionID(ctx, originalTransactionID)
	if err != nil {
		return nil, err
	}

	nextState, err := NextState(sub.State, event)
	if err != nil {
		return nil, err
	}

	sub.State = nextState
	sub.LastEventAt = s.now().UTC()
	if event == EventRenewalFailed {
		// period_end marks the start of grace; cron uses grace deadline = period_end + grace.
	}
	if err := s.store.UpdateSubscription(ctx, *sub); err != nil {
		return nil, err
	}
	return sub, nil
}

// RunExpiryScan applies cron fallback transitions for due subscriptions.
func (s *Service) RunExpiryScan(ctx context.Context) (int, error) {
	now := s.now().UTC()
	subs, err := s.store.ListSubscriptionsForExpiryScan(ctx, now)
	if err != nil {
		return 0, err
	}

	updated := 0
	for _, sub := range subs {
		event, ok := CronEventForSubscription(sub, now, s.grace)
		if !ok {
			continue
		}
		nextState, err := NextState(sub.State, event)
		if err != nil {
			continue
		}
		sub.State = nextState
		sub.LastEventAt = now
		if err := s.store.UpdateSubscription(ctx, sub); err != nil {
			return updated, err
		}
		updated++
	}
	return updated, nil
}

func (s *Service) duplicateVerifyResult(ctx context.Context, receipt *model.IAPReceipt) (VerifyResult, error) {
	sub, err := s.store.GetSubscriptionByOriginalTransactionID(ctx, receipt.OriginalTransactionID)
	if err != nil {
		return VerifyResult{}, err
	}
	result := verifyResultFromSubscription(*sub, true)
	return result, nil
}

func verifyResultFromSubscription(sub model.Subscription, duplicate bool) VerifyResult {
	return VerifyResult{
		SubscriptionID: sub.ID,
		State:          sub.State,
		SKU:            sub.SKU,
		PeriodStart:    sub.PeriodStart,
		PeriodEnd:      sub.PeriodEnd,
		AutoRenew:      sub.AutoRenew,
		Entitlements:   model.EntitlementsForState(sub.State),
		Duplicate:      duplicate,
	}
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

func resolvePeriod(verified *iap.VerifiedTransaction, catalog ProductCatalog, now time.Time) (time.Time, time.Time) {
	start := verified.PurchaseDate
	end := verified.ExpiresDate
	if start.IsZero() {
		start = now.UTC()
	}
	if end.IsZero() {
		if product, ok := catalog.ProductForID(verified.ProductID); ok {
			end = start.Add(product.Duration)
		} else {
			end = start.Add(30 * 24 * time.Hour)
		}
	}
	return start.UTC(), end.UTC()
}
