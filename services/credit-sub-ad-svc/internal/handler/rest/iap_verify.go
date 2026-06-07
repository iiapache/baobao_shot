package rest

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/baobao/credit-sub-ad-svc/internal/appattest"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/middleware"
)

var errEmptyBody = errors.New("empty body")

// IAPVerifyHandler serves POST /v1/credits/iap-verify.
type IAPVerifyHandler struct {
	iap       *iap.Service
	appAttest appattest.Verifier
}

// NewIAPVerifyHandler creates IAP verify REST handlers.
func NewIAPVerifyHandler(svc *iap.Service, verifier appattest.Verifier) *IAPVerifyHandler {
	if verifier == nil {
		verifier = appattest.DisabledVerifier{}
	}
	return &IAPVerifyHandler{iap: svc, appAttest: verifier}
}

type iapVerifyRequest struct {
	TransactionID     string `json:"transactionId"`
	SignedTransaction string `json:"signedTransaction"`
	ProductID         string `json:"productId"`
}

type iapVerifyResponseData struct {
	GrantedCredits int64  `json:"grantedCredits"`
	BalanceAfter   int64  `json:"balanceAfter"`
	TransactionID  string `json:"transactionId"`
	LedgerID       string `json:"ledgerId"`
	Duplicate      bool   `json:"duplicate,omitempty"`
}

// Verify handles POST /v1/credits/iap-verify (operationId: creditsIapVerify).
func (h *IAPVerifyHandler) Verify(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}
	if h.iap == nil {
		writeError(w, http.StatusServiceUnavailable, "COMMON_UPSTREAM", "iap service unavailable", r)
		return
	}

	var req iapVerifyRequest
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

	result, err := h.iap.Verify(r.Context(), iap.VerifyRequest{
		UserID:            userID,
		TransactionID:     req.TransactionID,
		SignedTransaction: req.SignedTransaction,
		ProductID:         req.ProductID,
	})
	if err != nil {
		writeIAPVerifyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, iapVerifyResponseData{
		GrantedCredits: result.GrantedCredits,
		BalanceAfter:   result.BalanceAfter,
		TransactionID:  result.TransactionID,
		LedgerID:       result.LedgerID,
		Duplicate:      result.Duplicate,
	})
}

func decodeIAPVerifyRequest(r *http.Request, dst *iapVerifyRequest) error {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		return err
	}
	if len(strings.TrimSpace(string(body))) == 0 {
		return errors.New("empty body")
	}
	return json.Unmarshal(body, dst)
}

func writeIAPVerifyError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, iap.ErrInvalidRequest):
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "transactionId, signedTransaction and productId required", r)
	case errors.Is(err, iap.ErrVerifyFailed):
		writeError(w, http.StatusUnprocessableEntity, "IAP_VERIFY_FAILED", "iap verification failed", r)
	case errors.Is(err, iap.ErrProductMismatch):
		writeError(w, http.StatusUnprocessableEntity, "IAP_PRODUCT_MISMATCH", "productId mismatch", r)
	case errors.Is(err, iap.ErrProductUnknown):
		writeError(w, http.StatusUnprocessableEntity, "IAP_PRODUCT_MISMATCH", "unknown productId", r)
	case errors.Is(err, iap.ErrUserMismatch):
		writeError(w, http.StatusConflict, "IAP_USER_MISMATCH", "transaction bound to another user", r)
	case errors.Is(err, iap.ErrTransactionMismatch):
		writeError(w, http.StatusUnprocessableEntity, "IAP_VERIFY_FAILED", "transactionId mismatch", r)
	default:
		writeError(w, http.StatusInternalServerError, "COMMON_INTERNAL", "iap verify failed", r)
	}
}
