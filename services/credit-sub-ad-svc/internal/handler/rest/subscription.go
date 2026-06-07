package rest

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/appattest"
	"github.com/baobao/credit-sub-ad-svc/internal/middleware"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/subscription"
)

// SubscriptionHandler serves subscription REST endpoints.
type SubscriptionHandler struct {
	svc       *subscription.Service
	appAttest appattest.Verifier
}

// NewSubscriptionHandler creates subscription REST handlers.
func NewSubscriptionHandler(svc *subscription.Service, verifier appattest.Verifier) *SubscriptionHandler {
	if verifier == nil {
		verifier = appattest.DisabledVerifier{}
	}
	return &SubscriptionHandler{svc: svc, appAttest: verifier}
}

type subscriptionIAPVerifyRequest struct {
	TransactionID     string `json:"transactionId"`
	SignedTransaction string `json:"signedTransaction"`
	ProductID         string `json:"productId"`
}

type subscriptionEntitlementsResponse struct {
	RemoveAds               bool `json:"removeAds"`
	BrandWatermarkRemovable bool `json:"brandWatermarkRemovable"`
	AllFilters              bool `json:"allFilters"`
	AnnualReviewRegen       bool `json:"annualReviewRegen"`
}

type subscriptionMeResponseData struct {
	Active          bool                             `json:"active"`
	State           string                           `json:"state"`
	SKU             string                           `json:"sku,omitempty"`
	PeriodStart     *time.Time                       `json:"periodStart,omitempty"`
	PeriodEnd       *time.Time                       `json:"periodEnd,omitempty"`
	AutoRenew       bool                             `json:"autoRenew,omitempty"`
	CacheTTLSeconds int                              `json:"cacheTtlSeconds"`
	Entitlements    subscriptionEntitlementsResponse `json:"entitlements"`
	SubscriptionID  string                           `json:"subscriptionId,omitempty"`
}

type subscriptionIAPVerifyResponseData struct {
	SubscriptionID string                           `json:"subscriptionId"`
	State          string                           `json:"state"`
	SKU            string                           `json:"sku"`
	PeriodStart    time.Time                        `json:"periodStart"`
	PeriodEnd      time.Time                        `json:"periodEnd"`
	AutoRenew      bool                             `json:"autoRenew"`
	Entitlements   subscriptionEntitlementsResponse `json:"entitlements"`
	Duplicate      bool                             `json:"duplicate,omitempty"`
}

// GetMe handles GET /v1/subscriptions/me.
func (h *SubscriptionHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}
	if h.svc == nil {
		writeError(w, http.StatusServiceUnavailable, "COMMON_UPSTREAM", "subscription service unavailable", r)
		return
	}

	result, err := h.svc.GetMe(r.Context(), userID)
	if err != nil {
		writeSubscriptionError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, subscriptionMeResponseData{
		Active:          result.Active,
		State:           result.State,
		SKU:             result.SKU,
		PeriodStart:     result.PeriodStart,
		PeriodEnd:       result.PeriodEnd,
		AutoRenew:       result.AutoRenew,
		CacheTTLSeconds: result.CacheTTLSeconds,
		Entitlements:    toEntitlementsResponse(result.Entitlements),
		SubscriptionID:  result.SubscriptionID,
	})
}

// Verify handles POST /v1/subscriptions/iap-verify.
func (h *SubscriptionHandler) Verify(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}
	if h.svc == nil {
		writeError(w, http.StatusServiceUnavailable, "COMMON_UPSTREAM", "subscription service unavailable", r)
		return
	}

	var req subscriptionIAPVerifyRequest
	body, err := readIAPVerifyBody(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json", r)
		return
	}
	if err := json.Unmarshal(body, &req); err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json", r)
		return
	}
	if !verifyAppAttest(w, r, h.appAttest, req.TransactionID, req.ProductID, body) {
		return
	}

	result, err := h.svc.Verify(r.Context(), subscription.VerifyRequest{
		UserID:            userID,
		TransactionID:     req.TransactionID,
		SignedTransaction: req.SignedTransaction,
		ProductID:         req.ProductID,
	})
	if err != nil {
		writeSubscriptionError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, subscriptionIAPVerifyResponseData{
		SubscriptionID: result.SubscriptionID,
		State:          string(result.State),
		SKU:            result.SKU,
		PeriodStart:    result.PeriodStart,
		PeriodEnd:      result.PeriodEnd,
		AutoRenew:      result.AutoRenew,
		Entitlements:   toEntitlementsResponse(result.Entitlements),
		Duplicate:      result.Duplicate,
	})
}

func decodeSubscriptionIAPVerifyRequest(r *http.Request, dst *subscriptionIAPVerifyRequest) error {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		return err
	}
	if len(strings.TrimSpace(string(body))) == 0 {
		return errors.New("empty body")
	}
	return json.Unmarshal(body, dst)
}

func toEntitlementsResponse(ent model.Entitlements) subscriptionEntitlementsResponse {
	return subscriptionEntitlementsResponse{
		RemoveAds:               ent.RemoveAds,
		BrandWatermarkRemovable: ent.BrandWatermarkRemovable,
		AllFilters:              ent.AllFilters,
		AnnualReviewRegen:       ent.AnnualReviewRegen,
	}
}

func writeSubscriptionError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, subscription.ErrInvalidRequest):
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "transactionId, signedTransaction and productId required", r)
	case errors.Is(err, subscription.ErrVerifyFailed):
		writeError(w, http.StatusUnprocessableEntity, "IAP_VERIFY_FAILED", "iap verification failed", r)
	case errors.Is(err, subscription.ErrProductMismatch):
		writeError(w, http.StatusUnprocessableEntity, "IAP_PRODUCT_MISMATCH", "productId mismatch", r)
	case errors.Is(err, subscription.ErrProductUnknown):
		writeError(w, http.StatusUnprocessableEntity, "IAP_PRODUCT_MISMATCH", "unknown productId", r)
	case errors.Is(err, subscription.ErrUserMismatch):
		writeError(w, http.StatusConflict, "IAP_USER_MISMATCH", "transaction bound to another user", r)
	case errors.Is(err, subscription.ErrTransactionMismatch):
		writeError(w, http.StatusUnprocessableEntity, "IAP_VERIFY_FAILED", "transactionId mismatch", r)
	default:
		writeError(w, http.StatusInternalServerError, "COMMON_INTERNAL", "subscription request failed", r)
	}
}
