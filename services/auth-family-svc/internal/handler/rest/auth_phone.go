package rest

import (
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"strings"

	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/baobao/auth-family-svc/internal/middleware"
)

// PhoneAuthHandler serves phone SMS auth endpoints.
type PhoneAuthHandler struct {
	phone *auth.PhoneAuthService
}

// NewPhoneAuthHandler creates handlers for phone auth routes.
func NewPhoneAuthHandler(phone *auth.PhoneAuthService) *PhoneAuthHandler {
	return &PhoneAuthHandler{phone: phone}
}

type phoneCodeRequest struct {
	Phone string `json:"phone"`
}

type phoneLoginRequest struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

type userProfileResponse struct {
	Nickname  string         `json:"nickname"`
	AvatarURL *string        `json:"avatarUrl"`
	Region    string         `json:"region"`
	Consents  map[string]bool `json:"consents"`
}

type authTokensResponse struct {
	UserID                string              `json:"userId"`
	IsNewUser             bool                `json:"isNewUser"`
	AccessToken           string              `json:"accessToken"`
	AccessTokenExpiresIn  int                 `json:"accessTokenExpiresIn"`
	RefreshToken          string              `json:"refreshToken"`
	RefreshTokenExpiresIn int                 `json:"refreshTokenExpiresIn"`
	Profile               userProfileResponse `json:"profile"`
}

// SendCode handles POST /v1/auth/phone/code.
func (h *PhoneAuthHandler) SendCode(w http.ResponseWriter, r *http.Request) {
	var req phoneCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Phone) == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "phone required",
			RequestID: requestID(r),
		})
		return
	}

	phone := strings.TrimSpace(req.Phone)
	if err := h.phone.SendCode(r.Context(), phone, clientIP(r)); err != nil {
		writePhoneAuthError(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		Message:   "ok",
		RequestID: requestID(r),
	})
}

// Login handles POST /v1/auth/phone/login.
func (h *PhoneAuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req phoneLoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil ||
		strings.TrimSpace(req.Phone) == "" || strings.TrimSpace(req.Code) == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "phone and code required",
			RequestID: requestID(r),
		})
		return
	}

	result, err := h.phone.Login(r.Context(), strings.TrimSpace(req.Phone), strings.TrimSpace(req.Code), clientIP(r), phoneDeviceID(r))
	if err != nil {
		writePhoneAuthError(w, r, err)
		return
	}

	user := result.User
	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		RequestID: requestID(r),
		Data: authTokensResponse{
			UserID:                user.ID,
			IsNewUser:             result.IsNewUser,
			AccessToken:           result.Tokens.AccessToken,
			AccessTokenExpiresIn:  result.Tokens.AccessTokenExpiresIn,
			RefreshToken:          result.Tokens.RefreshToken,
			RefreshTokenExpiresIn: result.Tokens.RefreshTokenExpiresIn,
			Profile: userProfileResponse{
				Nickname:  user.Nickname,
				AvatarURL: user.AvatarURL,
				Region:    user.Region,
				Consents: map[string]bool{
					"childData": user.HasChildDataConsent(),
				},
			},
		},
	})
}

func writePhoneAuthError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, auth.ErrRateLimited):
		writeJSON(w, http.StatusTooManyRequests, apiResponse{
			Code:      "COMMON_RATE_LIMIT",
			Message:   "too many requests",
			RequestID: requestID(r),
		})
	case errors.Is(err, auth.ErrInvalidPhone):
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "invalid phone",
			RequestID: requestID(r),
		})
	case errors.Is(err, auth.ErrInvalidCode):
		writeJSON(w, http.StatusUnauthorized, apiResponse{
			Code:      "AUTH_SMS_CODE_INVALID",
			Message:   "invalid or expired verification code",
			RequestID: requestID(r),
		})
	default:
		writeJSON(w, http.StatusInternalServerError, apiResponse{
			Code:      "SYS_INTERNAL",
			Message:   "internal error",
			RequestID: requestID(r),
		})
	}
}

func phoneDeviceID(r *http.Request) string {
	if id, ok := middleware.DeviceIDFromContext(r.Context()); ok && id != "" {
		return id
	}
	return "legacy-phone"
}

func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
