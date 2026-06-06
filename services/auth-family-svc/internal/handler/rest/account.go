package rest

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/account"
	"github.com/baobao/auth-family-svc/internal/consent"
	"github.com/baobao/auth-family-svc/internal/middleware"
	"github.com/baobao/auth-family-svc/internal/store"
)

// AccountHandler serves /v1/account profile, consent, deletion, and export endpoints.
type AccountHandler struct {
	users    store.UserStore
	consents *consent.Service
	accounts *account.Service
}

// NewAccountHandler creates account HTTP handlers.
func NewAccountHandler(users store.UserStore, consents *consent.Service, accounts *account.Service) *AccountHandler {
	return &AccountHandler{users: users, consents: consents, accounts: accounts}
}

type userProfileDTO struct {
	Nickname  string         `json:"nickname"`
	AvatarURL *string        `json:"avatarUrl"`
	Region    string         `json:"region"`
	Consents  map[string]bool `json:"consents"`
}

type childConsentRequest struct {
	Version  string `json:"version"`
	Accepted bool   `json:"accepted"`
}

type childConsentData struct {
	Version  string `json:"version"`
	AgreedAt string `json:"agreedAt"`
}

type deletionData struct {
	RequestedAt  string `json:"requestedAt"`
	ScheduledAt  string `json:"scheduledAt"`
	RevokeBefore string `json:"revokeBefore"`
}

type cancelDeletionData struct {
	CancelledAt string `json:"cancelledAt"`
	Restored    bool   `json:"restored"`
}

type exportRequestData struct {
	ExportID    string `json:"exportId"`
	Status      string `json:"status"`
	RequestedAt string `json:"requestedAt"`
}

// GetMe handles GET /v1/account/me.
func (h *AccountHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	user, err := h.users.FindByID(r.Context(), userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeAPI(w, http.StatusNotFound, "COMMON_NOT_FOUND", "user not found", r)
			return
		}
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
		return
	}

	hasConsent, err := h.consents.HasValidChildDataConsent(r.Context(), userID)
	if err != nil {
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, userProfileDTO{
		Nickname:  user.Nickname,
		AvatarURL: user.AvatarURL,
		Region:    user.Region,
		Consents: map[string]bool{
			"childData": hasConsent,
		},
	})
}

// SubmitChildDataConsent handles POST /v1/account/consents/child-data.
func (h *AccountHandler) SubmitChildDataConsent(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	var req childConsentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}

	deviceID, _ := middleware.DeviceIDFromContext(r.Context())
	record, err := h.consents.RecordChildDataConsent(
		r.Context(),
		userID,
		strings.TrimSpace(req.Version),
		req.Accepted,
		clientIP(r),
		deviceID,
	)
	if err != nil {
		mapConsentError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, childConsentData{
		Version:  record.Version,
		AgreedAt: record.AgreedAt.UTC().Format(time.RFC3339),
	})
}

// DeleteAccount handles DELETE /v1/account (soft delete + 7-day grace period).
func (h *AccountHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	result, err := h.accounts.RequestDeletion(r.Context(), userID)
	if err != nil {
		mapAccountError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, deletionData{
		RequestedAt:  result.RequestedAt.Format(time.RFC3339),
		ScheduledAt:  result.ScheduledAt.Format(time.RFC3339),
		RevokeBefore: result.RevokeBefore.Format(time.RFC3339),
	})
}

// CancelDeletion handles POST /v1/account/cancel-deletion.
func (h *AccountHandler) CancelDeletion(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	result, err := h.accounts.CancelDeletion(r.Context(), userID)
	if err != nil {
		mapAccountError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, cancelDeletionData{
		CancelledAt: result.CancelledAt.Format(time.RFC3339),
		Restored:    result.Restored,
	})
}

// RequestExport handles POST /v1/account/export (async export job entry point).
func (h *AccountHandler) RequestExport(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	result, err := h.accounts.RequestExport(r.Context(), userID)
	if err != nil {
		mapAccountError(w, r, err)
		return
	}

	writeAPI(w, http.StatusAccepted, "OK", "ok", r, exportRequestData{
		ExportID:    result.ExportID,
		Status:      result.Status,
		RequestedAt: result.RequestedAt.Format(time.RFC3339),
	})
}

func mapAccountError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, account.ErrUserNotFound), errors.Is(err, store.ErrNotFound):
		writeAPI(w, http.StatusNotFound, "COMMON_NOT_FOUND", "user not found", r)
	case errors.Is(err, account.ErrDeletionNotPending), errors.Is(err, store.ErrDeletionNotPending):
		writeAPI(w, http.StatusConflict, "ACCOUNT_DELETION_NOT_PENDING", "no pending account deletion", r)
	case errors.Is(err, account.ErrDeletionExpired), errors.Is(err, store.ErrDeletionExpired):
		writeAPI(w, http.StatusConflict, "ACCOUNT_DELETION_EXPIRED", "deletion grace period expired", r)
	case errors.Is(err, account.ErrAlreadyHardDeleted):
		writeAPI(w, http.StatusGone, "ACCOUNT_ALREADY_DELETED", "account permanently deleted", r)
	default:
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
	}
}

func mapConsentError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, consent.ErrNotAccepted):
		writeAPI(w, http.StatusUnprocessableEntity, "COMMON_BAD_PARAM", "consent must be accepted", r)
	case errors.Is(err, consent.ErrVersionMismatch):
		writeAPI(w, http.StatusUnprocessableEntity, "COMMON_BAD_PARAM", "consent version mismatch", r)
	case errors.Is(err, store.ErrNotFound):
		writeAPI(w, http.StatusNotFound, "COMMON_NOT_FOUND", "user not found", r)
	default:
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
	}
}
