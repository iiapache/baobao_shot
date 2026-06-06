package rest

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/baobao/auth-family-svc/internal/middleware"
)

// SessionHandler serves refresh and logout endpoints.
type SessionHandler struct {
	tokens *auth.TokenService
}

// NewSessionHandler creates session HTTP handlers.
func NewSessionHandler(tokens *auth.TokenService) *SessionHandler {
	return &SessionHandler{tokens: tokens}
}

type refreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type refreshTokenData struct {
	AccessToken           string `json:"accessToken"`
	AccessTokenExpiresIn  int    `json:"accessTokenExpiresIn"`
	RefreshToken          string `json:"refreshToken"`
	RefreshTokenExpiresIn int    `json:"refreshTokenExpiresIn"`
}

// Refresh handles POST /v1/auth/refresh.
func (h *SessionHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "invalid JSON body",
			RequestID: requestID(r),
		})
		return
	}

	req.RefreshToken = strings.TrimSpace(req.RefreshToken)
	if req.RefreshToken == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "refreshToken required",
			RequestID: requestID(r),
		})
		return
	}

	deviceID, ok := middleware.DeviceIDFromContext(r.Context())
	if !ok || deviceID == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "X-Device-Id header required",
			RequestID: requestID(r),
		})
		return
	}

	pair, err := h.tokens.Refresh(r.Context(), req.RefreshToken, deviceID)
	if err != nil {
		writeSessionError(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		Message:   "ok",
		RequestID: requestID(r),
		Data: refreshTokenData{
			AccessToken:           pair.AccessToken,
			AccessTokenExpiresIn:  pair.AccessTokenExpiresIn,
			RefreshToken:          pair.RefreshToken,
			RefreshTokenExpiresIn: pair.RefreshTokenExpiresIn,
		},
	})
}

// Logout handles POST /v1/account/logout.
func (h *SessionHandler) Logout(w http.ResponseWriter, r *http.Request) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
		writeJSON(w, http.StatusUnauthorized, apiResponse{
			Code:      "AUTH_TOKEN_EXPIRED",
			Message:   "authorization required",
			RequestID: requestID(r),
		})
		return
	}

	token := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
	if parseDevTokenForLogout(token) {
		writeJSON(w, http.StatusOK, apiResponse{
			Code:      "OK",
			Message:   "ok",
			RequestID: requestID(r),
		})
		return
	}

	if err := h.tokens.Logout(r.Context(), token); err != nil {
		writeSessionError(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		Message:   "ok",
		RequestID: requestID(r),
	})
}

func writeSessionError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, auth.ErrTokenExpired):
		writeJSON(w, http.StatusUnauthorized, apiResponse{
			Code:      "AUTH_TOKEN_EXPIRED",
			Message:   "access token expired",
			RequestID: requestID(r),
		})
	case errors.Is(err, auth.ErrTokenRevoked):
		writeJSON(w, http.StatusUnauthorized, apiResponse{
			Code:      "AUTH_TOKEN_REVOKED",
			Message:   "token revoked",
			RequestID: requestID(r),
		})
	case errors.Is(err, auth.ErrDeviceMismatch):
		writeJSON(w, http.StatusUnauthorized, apiResponse{
			Code:      "AUTH_DEVICE_MISMATCH",
			Message:   "device binding mismatch",
			RequestID: requestID(r),
		})
	case errors.Is(err, auth.ErrRefreshInvalid):
		writeJSON(w, http.StatusUnauthorized, apiResponse{
			Code:      "AUTH_REFRESH_INVALID",
			Message:   "refresh token invalid",
			RequestID: requestID(r),
		})
	default:
		writeJSON(w, http.StatusInternalServerError, apiResponse{
			Code:      "COMMON_INTERNAL",
			Message:   "internal error",
			RequestID: requestID(r),
		})
	}
}

func parseDevTokenForLogout(token string) bool {
	return token == "dev" || strings.HasPrefix(token, "dev:") || strings.HasPrefix(token, "atk_")
}
