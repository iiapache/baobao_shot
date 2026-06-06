package rest

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/baobao/auth-family-svc/internal/backup"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/go-chi/chi/v5"
)

// BackupHandler serves /v1/backup endpoints for credential hosting and status reporting.
type BackupHandler struct {
	svc *backup.Service
}

// NewBackupHandler creates backup HTTP handlers.
func NewBackupHandler(svc *backup.Service) *BackupHandler {
	return &BackupHandler{svc: svc}
}

type bindBackupProviderRequest struct {
	Kind              string            `json:"kind"`
	AccessToken       string            `json:"accessToken"`
	RefreshToken      *string           `json:"refreshToken,omitempty"`
	ExpiresAt         *string           `json:"expiresAt,omitempty"`
	ProviderAccountID *string           `json:"providerAccountId,omitempty"`
	Metadata          map[string]string `json:"metadata,omitempty"`
}

type backupProviderDTO struct {
	ID                string            `json:"id"`
	Kind              string            `json:"kind"`
	Status            string            `json:"status"`
	ProviderAccountID *string           `json:"providerAccountId,omitempty"`
	ExpiresAt         *string           `json:"expiresAt,omitempty"`
	Metadata          map[string]string `json:"metadata,omitempty"`
	CreatedAt         string            `json:"createdAt"`
	UpdatedAt         string            `json:"updatedAt"`
}

type backupStatusDTO struct {
	LastSuccessAt *string `json:"lastSuccessAt,omitempty"`
	LastAttemptAt *string `json:"lastAttemptAt,omitempty"`
	FailureCount  int     `json:"failureCount"`
	LastErrorCode *string `json:"lastErrorCode,omitempty"`
}

type reportBackupStatusRequest struct {
	Success     bool    `json:"success"`
	AttemptedAt string  `json:"attemptedAt"`
	ErrorCode   *string `json:"errorCode,omitempty"`
}

// BindProvider handles POST /v1/backup/providers.
func (h *BackupHandler) BindProvider(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	var req bindBackupProviderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}

	var expiresAt *time.Time
	if req.ExpiresAt != nil && *req.ExpiresAt != "" {
		parsed, err := time.Parse(time.RFC3339, *req.ExpiresAt)
		if err != nil {
			writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "expiresAt must be RFC3339", r)
			return
		}
		expiresAt = &parsed
	}

	provider, err := h.svc.BindProvider(r.Context(), userID, backup.BindInput{
		Kind:              req.Kind,
		AccessToken:       req.AccessToken,
		RefreshToken:      req.RefreshToken,
		ExpiresAt:         expiresAt,
		ProviderAccountID: req.ProviderAccountID,
		Metadata:          req.Metadata,
	})
	if err != nil {
		mapBackupError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, toBackupProviderDTO(provider))
}

// ListProviders handles GET /v1/backup/providers.
func (h *BackupHandler) ListProviders(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	providers, err := h.svc.ListProviders(r.Context(), userID)
	if err != nil {
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
		return
	}

	items := make([]backupProviderDTO, 0, len(providers))
	for i := range providers {
		items = append(items, toBackupProviderDTO(&providers[i]))
	}
	writeAPI(w, http.StatusOK, "OK", "", r, map[string]any{"items": items})
}

// UnbindProvider handles DELETE /v1/backup/providers/{id}.
func (h *BackupHandler) UnbindProvider(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	providerID := chi.URLParam(r, "id")
	if providerID == "" {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "id is required", r)
		return
	}

	if err := h.svc.UnbindProvider(r.Context(), userID, providerID); err != nil {
		mapBackupError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, map[string]string{"id": providerID})
}

// GetStatus handles GET /v1/backup/status.
func (h *BackupHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	status, err := h.svc.GetStatus(r.Context(), userID)
	if err != nil {
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, toBackupStatusDTO(status))
}

// ReportStatus handles POST /v1/backup/status.
func (h *BackupHandler) ReportStatus(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	var req reportBackupStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}

	var attemptedAt time.Time
	if req.AttemptedAt != "" {
		parsed, err := time.Parse(time.RFC3339, req.AttemptedAt)
		if err != nil {
			writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "attemptedAt must be RFC3339", r)
			return
		}
		attemptedAt = parsed
	}

	status, err := h.svc.ReportStatus(r.Context(), userID, backup.ReportStatusInput{
		Success:     req.Success,
		AttemptedAt: attemptedAt,
		ErrorCode:   req.ErrorCode,
	})
	if err != nil {
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, toBackupStatusDTO(status))
}

func mapBackupError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, backup.ErrInvalidKind):
		writeAPI(w, http.StatusBadRequest, "BACKUP_INVALID_PROVIDER", "invalid backup provider kind", r)
	case errors.Is(err, backup.ErrTokenRequired):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "access token required for baidu_pan", r)
	case errors.Is(err, backup.ErrNotFound):
		writeAPI(w, http.StatusNotFound, "COMMON_NOT_FOUND", "backup provider not found", r)
	default:
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "internal error", r)
	}
}

func toBackupProviderDTO(provider *model.BackupProvider) backupProviderDTO {
	dto := backupProviderDTO{
		ID:                provider.ID,
		Kind:              provider.Kind,
		Status:            string(provider.Status),
		ProviderAccountID: provider.ProviderAccountID,
		Metadata:          provider.Metadata,
		CreatedAt:         provider.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:         provider.UpdatedAt.UTC().Format(time.RFC3339),
	}
	if provider.ExpiresAt != nil {
		formatted := provider.ExpiresAt.UTC().Format(time.RFC3339)
		dto.ExpiresAt = &formatted
	}
	if dto.Metadata == nil {
		dto.Metadata = map[string]string{}
	}
	return dto
}

func toBackupStatusDTO(status *model.BackupStatus) backupStatusDTO {
	dto := backupStatusDTO{FailureCount: status.FailureCount}
	if status.LastSuccessAt != nil {
		formatted := status.LastSuccessAt.UTC().Format(time.RFC3339)
		dto.LastSuccessAt = &formatted
	}
	if status.LastAttemptAt != nil {
		formatted := status.LastAttemptAt.UTC().Format(time.RFC3339)
		dto.LastAttemptAt = &formatted
	}
	dto.LastErrorCode = status.LastErrorCode
	return dto
}
