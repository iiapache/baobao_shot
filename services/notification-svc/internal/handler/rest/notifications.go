package rest

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/baobao/notification-svc/internal/inbox"
	"github.com/baobao/notification-svc/internal/middleware"
)

const (
	defaultNotificationLimit = 50
	maxNotificationLimit     = 50
)

// NotificationHandler serves message center REST APIs.
type NotificationHandler struct {
	svc *inbox.Service
}

// NewNotificationHandler creates REST handlers for notifications.
func NewNotificationHandler(svc *inbox.Service) *NotificationHandler {
	return &NotificationHandler{svc: svc}
}

// List handles GET /v1/notifications.
func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeAPI(w, http.StatusUnauthorized, "AUTH_TOKEN_EXPIRED", "authentication required", r)
		return
	}

	limit, err := parseNotificationLimit(r.URL.Query().Get("limit"))
	if err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid limit", r)
		return
	}

	data, err := h.svc.List(r.Context(), inbox.ListInput{
		UserID: userID,
		Cursor: r.URL.Query().Get("cursor"),
		Limit:  limit,
	})
	if err != nil {
		h.writeInboxError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, data)
}

type markReadRequest struct {
	IDs []string `json:"ids"`
	All bool     `json:"all"`
}

// MarkRead handles POST /v1/notifications/mark-read.
func (h *NotificationHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeAPI(w, http.StatusUnauthorized, "AUTH_TOKEN_EXPIRED", "authentication required", r)
		return
	}

	var req markReadRequest
	if r.Body != nil && r.ContentLength != 0 {
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid JSON body", r)
			return
		}
	}

	data, err := h.svc.MarkRead(r.Context(), inbox.MarkReadInput{
		UserID: userID,
		IDs:    req.IDs,
		All:    req.All,
	})
	if err != nil {
		h.writeInboxError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, data)
}

// GetSubscriptions handles GET /v1/notifications/subscriptions.
func (h *NotificationHandler) GetSubscriptions(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeAPI(w, http.StatusUnauthorized, "AUTH_TOKEN_EXPIRED", "authentication required", r)
		return
	}

	data, err := h.svc.GetSubscriptions(r.Context(), userID)
	if err != nil {
		h.writeInboxError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, data)
}

type patchSubscriptionsRequest struct {
	Subscriptions []inbox.SubscriptionPatchItem `json:"subscriptions"`
}

// UpdateSubscriptions handles PATCH /v1/notifications/subscriptions.
func (h *NotificationHandler) UpdateSubscriptions(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeAPI(w, http.StatusUnauthorized, "AUTH_TOKEN_EXPIRED", "authentication required", r)
		return
	}

	var req patchSubscriptionsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid JSON body", r)
		return
	}

	data, err := h.svc.UpdateSubscriptions(r.Context(), userID, req.Subscriptions)
	if err != nil {
		h.writeInboxError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, data)
}

func (h *NotificationHandler) writeInboxError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, inbox.ErrInvalidCursor):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid cursor", r)
	case errors.Is(err, inbox.ErrInvalidCategory):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid notification category", r)
	case errors.Is(err, inbox.ErrBadRequest):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid request", r)
	default:
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
	}
}

func parseNotificationLimit(raw string) (int, error) {
	if raw == "" {
		return defaultNotificationLimit, nil
	}
	limit, err := strconv.Atoi(raw)
	if err != nil || limit < 1 {
		return 0, errors.New("invalid limit")
	}
	if limit > maxNotificationLimit {
		return maxNotificationLimit, nil
	}
	return limit, nil
}
