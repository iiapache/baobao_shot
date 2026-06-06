package rest

import (
	"encoding/json"
	"net/http"
	"sync/atomic"
)

type HealthHandler struct {
	serviceName string
	ready       atomic.Bool
}

func NewHealthHandler(serviceName string) *HealthHandler {
	h := &HealthHandler{serviceName: serviceName}
	h.ready.Store(true)
	return h
}

type healthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service"`
}

func (h *HealthHandler) Live(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, healthResponse{Status: "ok", Service: h.serviceName})
}

func (h *HealthHandler) Ready(w http.ResponseWriter, _ *http.Request) {
	if !h.ready.Load() {
		writeJSON(w, http.StatusServiceUnavailable, healthResponse{Status: "not_ready", Service: h.serviceName})
		return
	}
	writeJSON(w, http.StatusOK, healthResponse{Status: "ready", Service: h.serviceName})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	if status != http.StatusOK {
		w.WriteHeader(status)
	}
	_ = json.NewEncoder(w).Encode(v)
}
