package rest

import (
	"errors"
	"net/http"

	"github.com/baobao/credit-sub-ad-svc/internal/middleware"
	"github.com/baobao/credit-sub-ad-svc/internal/signin"
)

// SignInHandler serves POST /v1/credits/sign-in.
type SignInHandler struct {
	signIn *signin.Service
}

// NewSignInHandler creates sign-in REST handlers.
func NewSignInHandler(svc *signin.Service) *SignInHandler {
	return &SignInHandler{signIn: svc}
}

type signInResponseData struct {
	GrantedCredits int64  `json:"grantedCredits"`
	BalanceAfter   int64  `json:"balanceAfter"`
	Streak         int    `json:"streak"`
	LedgerID       string `json:"ledgerId"`
}

// SignIn handles POST /v1/credits/sign-in (operationId: creditsSignIn).
func (h *SignInHandler) SignIn(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}
	if h.signIn == nil {
		writeError(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "sign-in service unavailable", r)
		return
	}

	result, err := h.signIn.SignIn(r.Context(), userID)
	if err != nil {
		writeSignInError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, signInResponseData{
		GrantedCredits: result.GrantedCredits,
		BalanceAfter:   result.BalanceAfter,
		Streak:         result.Streak,
		LedgerID:       result.LedgerID,
	})
}

func writeSignInError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, signin.ErrInvalidRequest):
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid request", r)
	case errors.Is(err, signin.ErrSignInDone):
		writeError(w, http.StatusConflict, "CREDIT_SIGN_IN_DONE", "already signed in today", r)
	default:
		writeError(w, http.StatusInternalServerError, "SYS_INTERNAL", "sign-in failed", r)
	}
}
