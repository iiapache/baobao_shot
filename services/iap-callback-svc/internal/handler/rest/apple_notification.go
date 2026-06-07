package rest

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/baobao/iap-callback-svc/internal/processor"
)

// AppleNotificationHandler serves Apple Server Notifications v2 callbacks.
type AppleNotificationHandler struct {
	processor *processor.Service
}

// NewAppleNotificationHandler creates ASN HTTP handlers.
func NewAppleNotificationHandler(svc *processor.Service) *AppleNotificationHandler {
	return &AppleNotificationHandler{processor: svc}
}

type appleNotificationRequest struct {
	SignedPayload string `json:"signedPayload"`
}

type appleNotificationResponse struct {
	Status           string `json:"status"`
	NotificationUUID string `json:"notificationUUID,omitempty"`
	EventType        string `json:"eventType,omitempty"`
	TransactionID    string `json:"transactionId,omitempty"`
	Duplicate        bool   `json:"duplicate,omitempty"`
}

// Notify handles POST /v1/apple/notifications (Apple ASN v2).
func (h *AppleNotificationHandler) Notify(w http.ResponseWriter, r *http.Request) {
	if h.processor == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "unavailable"})
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"status": "invalid"})
		return
	}

	var req appleNotificationRequest
	if err := json.Unmarshal(body, &req); err != nil || req.SignedPayload == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"status": "invalid"})
		return
	}

	result, err := h.processor.Handle(r.Context(), req.SignedPayload)
	if errors.Is(err, processor.ErrInvalidRequest) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"status": "invalid"})
		return
	}
	if errors.Is(err, processor.ErrDuplicate) {
		writeJSON(w, http.StatusOK, appleNotificationResponse{
			Status:           "duplicate",
			NotificationUUID: result.NotificationUUID,
			Duplicate:        true,
		})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"status": "error"})
		return
	}

	writeJSON(w, http.StatusOK, appleNotificationResponse{
		Status:           "ok",
		NotificationUUID: result.NotificationUUID,
		EventType:        result.EventType,
		TransactionID:    result.TransactionID,
	})
}
