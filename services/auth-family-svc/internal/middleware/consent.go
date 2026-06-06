package middleware

import (
	"encoding/json"
	"net/http"

	"github.com/baobao/auth-family-svc/internal/consent"
)

type consentErrorResponse struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"requestId"`
}

// RequireChildConsent blocks the request when the user has not agreed to the current consent version.
func RequireChildConsent(svc *consent.Service) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID, ok := UserIDFromContext(r.Context())
			if !ok {
				writeConsentError(w, r, http.StatusUnauthorized, "AUTH_UNAUTHORIZED", "authentication required")
				return
			}

			hasConsent, err := svc.HasValidChildDataConsent(r.Context(), userID)
			if err != nil {
				writeConsentError(w, r, http.StatusInternalServerError, "SYS_INTERNAL", "internal error")
				return
			}
			if !hasConsent {
				writeConsentError(w, r, http.StatusUnprocessableEntity, "ACCOUNT_CONSENT_REQUIRED", "child data consent required")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

func writeConsentError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(consentErrorResponse{
		Code:      code,
		Message:   message,
		RequestID: requestIDFromRequest(r),
	})
}

func requestIDFromRequest(r *http.Request) string {
	if id := r.Header.Get("X-Request-Id"); id != "" {
		return id
	}
	if id := r.Header.Get("X-Trace-Id"); id != "" {
		return id
	}
	return "req_consent"
}
