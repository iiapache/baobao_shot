package rest

import (
	"encoding/json"
	"net/http"

	"github.com/baobao/config-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// AdminHandler serves emergency ops endpoints (T7.14 kill-switch).
type AdminHandler struct {
	store *store.MemoryStore
	token string
}

// NewAdminHandler creates admin handlers; token empty disables admin routes.
func NewAdminHandler(s store.Store, adminToken string) *AdminHandler {
	mem, _ := s.(*store.MemoryStore)
	return &AdminHandler{store: mem, token: adminToken}
}

type patchFeatureBody struct {
	DefaultEnabled *bool   `json:"defaultEnabled"`
	RolloutPercent *int    `json:"rolloutPercent"`
	Variant        *string `json:"variant"`
}

type patchPlayBody struct {
	Enabled *bool `json:"enabled"`
}

func (h *AdminHandler) requireAdmin(w http.ResponseWriter, r *http.Request) bool {
	if h.store == nil {
		writeJSON(w, http.StatusServiceUnavailable, apiResponse{
			Code:      "CONFIG_ADMIN_UNAVAILABLE",
			Message:   "admin API requires memory storage backend",
			RequestID: requestID(r),
		})
		return false
	}
	if h.token == "" {
		writeJSON(w, http.StatusServiceUnavailable, apiResponse{
			Code:      "CONFIG_ADMIN_DISABLED",
			Message:   "CONFIG_ADMIN_TOKEN not configured",
			RequestID: requestID(r),
		})
		return false
	}
	if r.Header.Get("X-Admin-Token") != h.token {
		writeJSON(w, http.StatusUnauthorized, apiResponse{
			Code:      "COMMON_UNAUTHORIZED",
			Message:   "invalid or missing X-Admin-Token",
			RequestID: requestID(r),
		})
		return false
	}
	return true
}

// PatchFeature handles PATCH /v1/admin/features/{key}.
func (h *AdminHandler) PatchFeature(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(w, r) {
		return
	}
	key := chi.URLParam(r, "key")
	if key == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "feature key required",
			RequestID: requestID(r),
		})
		return
	}

	var body patchFeatureBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "invalid JSON body",
			RequestID: requestID(r),
		})
		return
	}

	if err := h.store.PatchFeature(key, store.FeaturePatch{
		DefaultEnabled: body.DefaultEnabled,
		RolloutPercent: body.RolloutPercent,
		Variant:        body.Variant,
	}); err != nil {
		writeJSON(w, http.StatusNotFound, apiResponse{
			Code:      "CONFIG_FLAG_NOT_FOUND",
			Message:   err.Error(),
			RequestID: requestID(r),
		})
		return
	}

	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		RequestID: requestID(r),
		Data:      map[string]string{"key": key, "status": "updated"},
	})
}

// PatchPlay handles PATCH /v1/admin/plays/{id}.
func (h *AdminHandler) PatchPlay(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(w, r) {
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "play id required",
			RequestID: requestID(r),
		})
		return
	}

	var body patchPlayBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "invalid JSON body",
			RequestID: requestID(r),
		})
		return
	}

	if err := h.store.PatchPlay(id, store.PlayPatch{Enabled: body.Enabled}); err != nil {
		writeJSON(w, http.StatusNotFound, apiResponse{
			Code:      "CONFIG_PLAY_NOT_FOUND",
			Message:   err.Error(),
			RequestID: requestID(r),
		})
		return
	}

	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		RequestID: requestID(r),
		Data:      map[string]string{"id": id, "status": "updated"},
	})
}
