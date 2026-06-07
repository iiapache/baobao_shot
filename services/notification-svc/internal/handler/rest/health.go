package rest

import (
	"encoding/json"
	"net/http"
	"sync/atomic"

	"github.com/google/uuid"
)

type apiResponse struct {
	Code      string `json:"code"`
	Message   string `json:"message,omitempty"`
	RequestID string `json:"requestId"`
	Data      any    `json:"data,omitempty"`
}

func requestID(r *http.Request) string {
	if id := r.Header.Get("X-Request-Id"); id != "" {
		return id
	}
	if id := r.Header.Get("X-Trace-Id"); id != "" {
		return id
	}
	return "req_" + uuid.NewString()[:8]
}

func writeAPI(w http.ResponseWriter, status int, code, message string, r *http.Request, data ...any) {
	resp := apiResponse{
		Code:      code,
		Message:   message,
		RequestID: requestID(r),
	}
	if len(data) > 0 {
		resp.Data = data[0]
	}
	writeJSON(w, status, resp)
}

// HealthHandler serves liveness and readiness probes.
type HealthHandler struct {
	serviceName string
	ready       atomic.Bool
}

// NewHealthHandler creates probe handlers for the given service.
func NewHealthHandler(serviceName string) *HealthHandler {
	h := &HealthHandler{serviceName: serviceName}
	h.ready.Store(true)
	return h
}

type healthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service"`
}

// Live handles GET /health — always OK when process is up.
func (h *HealthHandler) Live(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, healthResponse{Status: "ok", Service: h.serviceName})
}

// Ready handles GET /ready — OK when dependencies are ready.
func (h *HealthHandler) Ready(w http.ResponseWriter, _ *http.Request) {
	if !h.ready.Load() {
		writeJSON(w, http.StatusServiceUnavailable, healthResponse{Status: "not_ready", Service: h.serviceName})
		return
	}
	writeJSON(w, http.StatusOK, healthResponse{Status: "ready", Service: h.serviceName})
}

// SetReady toggles readiness (for startup hooks or dependency checks).
func (h *HealthHandler) SetReady(ready bool) {
	h.ready.Store(ready)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
