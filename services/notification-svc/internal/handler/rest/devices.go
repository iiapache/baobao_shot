package rest

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/baobao/notification-svc/internal/device"
	"github.com/baobao/notification-svc/internal/middleware"
	"github.com/go-chi/chi/v5"
)

// DeviceHandler serves device token registration APIs.
type DeviceHandler struct {
	svc *device.Service
}

// NewDeviceHandler creates REST handlers for device tokens.
func NewDeviceHandler(svc *device.Service) *DeviceHandler {
	return &DeviceHandler{svc: svc}
}

type registerDeviceRequest struct {
	DeviceID   string `json:"deviceId"`
	APNSToken  string `json:"apnsToken"`
	AppVersion string `json:"appVersion"`
	OSVersion  string `json:"osVersion"`
	Model      string `json:"model"`
}

type registerDeviceResponse struct {
	DeviceID  string `json:"deviceId"`
	APNSToken string `json:"apnsToken"`
	Region    string `json:"region"`
}

// Register handles POST /v1/notifications/devices.
func (h *DeviceHandler) Register(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeAPI(w, http.StatusUnauthorized, "AUTH_TOKEN_EXPIRED", "authentication required", r)
		return
	}

	region, ok := middleware.RegionFromContext(r.Context())
	if !ok {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "X-Region header required (cn|os)", r)
		return
	}

	var req registerDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid JSON body", r)
		return
	}

	dt, err := h.svc.Register(r.Context(), userID, device.RegisterInput{
		DeviceID:   req.DeviceID,
		APNSToken:  req.APNSToken,
		AppVersion: req.AppVersion,
		OSVersion:  req.OSVersion,
		Model:      req.Model,
		Region:     region,
	})
	if err != nil {
		h.writeRegisterError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, registerDeviceResponse{
		DeviceID:  dt.DeviceID,
		APNSToken: dt.APNSToken,
		Region:    dt.Region,
	})
}

// Unregister handles DELETE /v1/notifications/devices/{deviceId}.
func (h *DeviceHandler) Unregister(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeAPI(w, http.StatusUnauthorized, "AUTH_TOKEN_EXPIRED", "authentication required", r)
		return
	}

	deviceID := chi.URLParam(r, "deviceId")
	if err := h.svc.Unregister(r.Context(), userID, deviceID); err != nil {
		switch {
		case errors.Is(err, device.ErrDeviceNotFound):
			writeAPI(w, http.StatusNotFound, "COMMON_NOT_FOUND", "device not found", r)
		case errors.Is(err, device.ErrBadRequest):
			writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "deviceId required", r)
		default:
			writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
		}
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r)
}

type cleanupTokenRequest struct {
	APNSToken string `json:"apnsToken"`
}

type cleanupTokenResponse struct {
	Removed int64 `json:"removed"`
}

// CleanupInvalidToken handles POST /v1/internal/notifications/tokens/cleanup.
func (h *DeviceHandler) CleanupInvalidToken(w http.ResponseWriter, r *http.Request) {
	var req cleanupTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid JSON body", r)
		return
	}

	removed, err := h.svc.CleanupInvalidToken(r.Context(), req.APNSToken)
	if err != nil {
		if errors.Is(err, device.ErrInvalidToken) {
			writeAPI(w, http.StatusUnprocessableEntity, "NOTIF_TOKEN_INVALID", "apns token invalid", r)
			return
		}
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, cleanupTokenResponse{Removed: removed})
}

func (h *DeviceHandler) writeRegisterError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, device.ErrBadRequest):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "deviceId and apnsToken required", r)
	case errors.Is(err, device.ErrInvalidToken):
		writeAPI(w, http.StatusUnprocessableEntity, "NOTIF_TOKEN_INVALID", "apns token invalid", r)
	default:
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
	}
}
