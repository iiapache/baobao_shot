package rest

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/baobao/auth-family-svc/internal/middleware"
)

// AuthHandler serves authentication endpoints.
type AuthHandler struct {
	auth *auth.Service
}

// NewAuthHandler creates auth HTTP handlers.
func NewAuthHandler(svc *auth.Service) *AuthHandler {
	return &AuthHandler{auth: svc}
}

type appleLoginRequest struct {
	IdentityToken     string `json:"identityToken"`
	AuthorizationCode string `json:"authorizationCode"`
	Nickname          string `json:"nickname"`
	Region            string `json:"region"`
}

type appleLoginData struct {
	UserID                string       `json:"userId"`
	IsNewUser             bool         `json:"isNewUser"`
	AccessToken           string       `json:"accessToken"`
	AccessTokenExpiresIn  int          `json:"accessTokenExpiresIn"`
	RefreshToken          string       `json:"refreshToken"`
	RefreshTokenExpiresIn int          `json:"refreshTokenExpiresIn"`
	Profile               auth.Profile `json:"profile"`
}

// AppleLogin handles POST /v1/auth/apple.
func (h *AuthHandler) AppleLogin(w http.ResponseWriter, r *http.Request) {
	var req appleLoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "invalid JSON body",
			RequestID: requestID(r),
		})
		return
	}

	req.IdentityToken = strings.TrimSpace(req.IdentityToken)
	req.AuthorizationCode = strings.TrimSpace(req.AuthorizationCode)
	req.Region = strings.ToLower(strings.TrimSpace(req.Region))

	if req.IdentityToken == "" || req.AuthorizationCode == "" || req.Region == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "identityToken, authorizationCode and region are required",
			RequestID: requestID(r),
		})
		return
	}
	if req.Region != "cn" && req.Region != "os" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "region must be cn or os",
			RequestID: requestID(r),
		})
		return
	}

	headerRegion, ok := middleware.RegionFromContext(r.Context())
	if !ok || headerRegion == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "X-Region header required (cn|os)",
			RequestID: requestID(r),
		})
		return
	}
	if _, ok := middleware.AppVersionFromContext(r.Context()); !ok {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "X-App-Version header required",
			RequestID: requestID(r),
		})
		return
	}
	if _, ok := middleware.DeviceIDFromContext(r.Context()); !ok {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "X-Device-Id header required",
			RequestID: requestID(r),
		})
		return
	}
	deviceID, _ := middleware.DeviceIDFromContext(r.Context())
	if headerRegion != req.Region {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "region in body must match X-Region header",
			RequestID: requestID(r),
		})
		return
	}

	result, err := h.auth.AppleLogin(r.Context(), auth.AppleLoginInput{
		IdentityToken:     req.IdentityToken,
		AuthorizationCode: req.AuthorizationCode,
		Nickname:          req.Nickname,
		Region:            req.Region,
		DeviceID:          deviceID,
	})
	if err != nil {
		if errors.Is(err, auth.ErrInvalidAppleToken) {
			writeJSON(w, http.StatusUnauthorized, apiResponse{
				Code:      "AUTH_APPLE_INVALID",
				Message:   "apple identity token invalid",
				RequestID: requestID(r),
			})
			return
		}
		writeJSON(w, http.StatusInternalServerError, apiResponse{
			Code:      "COMMON_INTERNAL",
			Message:   "internal error",
			RequestID: requestID(r),
		})
		return
	}

	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		Message:   "ok",
		RequestID: requestID(r),
		Data: appleLoginData{
			UserID:                result.UserID,
			IsNewUser:             result.IsNewUser,
			AccessToken:           result.AccessToken,
			AccessTokenExpiresIn:  result.AccessTokenExpiresIn,
			RefreshToken:          result.RefreshToken,
			RefreshTokenExpiresIn: result.RefreshTokenExpiresIn,
			Profile:               result.Profile,
		},
	})
}
