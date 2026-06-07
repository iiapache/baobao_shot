package rest

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/middleware"
)

// DebugHandler exposes staging smoke-test endpoints.
type DebugHandler struct {
	apns     *apns.Client
	simulated bool
}

// NewDebugHandler creates debug handlers when DEBUG_ENDPOINTS is enabled.
func NewDebugHandler(client *apns.Client, simulated bool) *DebugHandler {
	return &DebugHandler{apns: client, simulated: simulated}
}

type apnsPingRequest struct {
	DeviceToken string `json:"device_token"`
	Title       string `json:"title"`
	Body        string `json:"body"`
	Region      string `json:"region"`
}

type apnsPingResponse struct {
	APNSID     string `json:"apnsId"`
	StatusCode int    `json:"statusCode"`
	Host       string `json:"host"`
	Region     string `json:"region"`
	Simulated  bool   `json:"simulated"`
}

// APNsPing handles POST /v1/debug/apns-ping (mock APNs push demo).
func (h *DebugHandler) APNsPing(w http.ResponseWriter, r *http.Request) {
	if h.apns == nil {
		writeAPI(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "apns client not configured", r)
		return
	}

	var req apnsPingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid JSON body", r)
		return
	}

	token := strings.TrimSpace(req.DeviceToken)
	if token == "" {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "device_token required", r)
		return
	}

	regionStr, ok := middleware.RegionFromContext(r.Context())
	if !ok {
		regionStr = strings.ToLower(strings.TrimSpace(req.Region))
	}
	if regionStr == "" {
		regionStr = "cn"
	}
	region := apns.Region(regionStr)

	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = "BabyCamera"
	}
	body := strings.TrimSpace(req.Body)
	if body == "" {
		body = "APNs smoke test"
	}

	host, _ := h.apns.PoolHost(region)
	result, err := h.apns.Send(r.Context(), region, apns.PushPayload{
		DeviceToken: token,
		Title:       title,
		Body:        body,
		Priority:    10,
	})

	resp := apnsPingResponse{
		APNSID:     result.APNSID,
		StatusCode: result.StatusCode,
		Host:       host,
		Region:     string(region),
		Simulated:  h.simulated,
	}

	if err != nil {
		if errors.Is(err, apns.ErrTokenInvalid) || result.TokenInvalid {
			writeAPI(w, http.StatusUnprocessableEntity, "NOTIF_TOKEN_INVALID", "apns token invalid", r, resp)
			return
		}
		writeAPI(w, http.StatusBadGateway, "SYS_UPSTREAM_UNAVAILABLE", err.Error(), r, resp)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, resp)
}
