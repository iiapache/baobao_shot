package rest

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/family"
	"github.com/baobao/auth-family-svc/internal/middleware"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// NewFamilyHandler creates family REST handlers.
func NewFamilyHandler(cfg *config.Config, s store.Store) *FamilyHandler {
	inviteSecret := ""
	appScheme := "baobao://invite"
	if cfg != nil {
		inviteSecret = cfg.InviteSigningSecret
		appScheme = cfg.AppScheme
	}
	return &FamilyHandler{svc: family.NewService(s, appScheme, inviteSecret), store: s}
}

// FamilyHandler serves /v1/families endpoints.
type FamilyHandler struct {
	svc   *family.Service
	store store.Store
}

type createFamilyRequest struct {
	Name string `json:"name"`
}

type updateFamilyRequest struct {
	Name string `json:"name"`
}

type familySummaryDTO struct {
	FamilyID string `json:"familyId"`
	Name     string `json:"name"`
	Role     string `json:"role"`
}

type familyMemberDTO struct {
	UserID   string `json:"userId"`
	Role     string `json:"role"`
	Nickname string `json:"nickname,omitempty"`
	JoinedAt string `json:"joinedAt"`
}

type familyDetailDTO struct {
	FamilyID string            `json:"familyId"`
	Name     string            `json:"name"`
	Role     string            `json:"role"`
	Members  []familyMemberDTO `json:"members"`
	Babies   []any             `json:"babies"`
}

// Create handles POST /v1/families.
func (h *FamilyHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	var req createFamilyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}

	region, ok := middleware.RegionFromContext(r.Context())
	if !ok || (region != "cn" && region != "os") {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "X-Region header required (cn|os)", r)
		return
	}

	f, role, err := h.svc.CreateFamily(r.Context(), userID, req.Name, region)
	if err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, familySummaryDTO{
		FamilyID: f.ID,
		Name:     f.Name,
		Role:     string(role),
	})
}

// ListMine handles GET /v1/families.
func (h *FamilyHandler) ListMine(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}

	items, err := h.svc.ListMine(r.Context(), userID)
	if err != nil {
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", err.Error(), r)
		return
	}

	dtos := make([]familySummaryDTO, 0, len(items))
	for _, item := range items {
		dtos = append(dtos, familySummaryDTO{
			FamilyID: item.Family.ID,
			Name:     item.Family.Name,
			Role:     string(item.Role),
		})
	}

	writeAPI(w, http.StatusOK, "OK", "", r, map[string]any{"items": dtos})
}

// Get handles GET /v1/families/{familyId}.
func (h *FamilyHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")

	detail, err := h.svc.GetDetail(r.Context(), familyID, userID)
	if err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, toFamilyDetailDTO(r.Context(), h.store, detail))
}

// Update handles PATCH /v1/families/{familyId}.
func (h *FamilyHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")

	var req updateFamilyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}

	f, err := h.svc.UpdateName(r.Context(), familyID, userID, req.Name)
	if err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, familySummaryDTO{
		FamilyID: f.ID,
		Name:     f.Name,
	})
}

type transferAdminRequest struct {
	TargetUserID string `json:"targetUserId"`
}

type transferAdminResponseDTO struct {
	FamilyID            string `json:"familyId"`
	PreviousAdminUserID string `json:"previousAdminUserId"`
	NewAdminUserID      string `json:"newAdminUserId"`
	TransferredAt       string `json:"transferredAt"`
}

type takeoverRequest struct {
	Choice string `json:"choice"`
}

// TransferAdmin handles POST /v1/families/{familyId}/transfer.
func (h *FamilyHandler) TransferAdmin(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")

	var req transferAdminRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}
	if req.TargetUserID == "" {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "targetUserId is required", r)
		return
	}

	result, err := h.svc.TransferAdmin(r.Context(), familyID, userID, req.TargetUserID)
	if err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, transferAdminResponseDTO{
		FamilyID:            result.FamilyID,
		PreviousAdminUserID: result.PreviousAdminUserID,
		NewAdminUserID:      result.NewAdminUserID,
		TransferredAt:       result.TransferredAt,
	})
}

// Takeover handles POST /v1/families/{familyId}/takeover.
func (h *FamilyHandler) Takeover(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")

	var req takeoverRequest
	if r.ContentLength != 0 {
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
			return
		}
	}

	result, err := h.svc.Takeover(r.Context(), familyID, userID, family.TakeoverInput{Choice: req.Choice})
	if err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, result)
}

// Delete handles DELETE /v1/families/{familyId}.
func (h *FamilyHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")

	if err := h.svc.Dissolve(r.Context(), familyID, userID); err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, map[string]string{"familyId": familyID})
}

func requireUser(w http.ResponseWriter, r *http.Request) (string, bool) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeAPI(w, http.StatusUnauthorized, "AUTH_UNAUTHORIZED", "authentication required", r)
		return "", false
	}
	return userID, true
}

func mapFamilyError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, family.ErrCreateLimit):
		writeAPI(w, http.StatusConflict, "FAMILY_CREATE_LIMIT", "family create limit reached", r)
	case errors.Is(err, family.ErrJoinLimit):
		writeAPI(w, http.StatusConflict, "FAMILY_JOIN_LIMIT", "family join limit reached", r)
	case errors.Is(err, family.ErrNotFound):
		writeAPI(w, http.StatusNotFound, "FAMILY_NOT_FOUND", "family not found", r)
	case errors.Is(err, family.ErrNotAdmin):
		writeAPI(w, http.StatusForbidden, "FAMILY_NOT_ADMIN", "admin role required", r)
	case errors.Is(err, family.ErrInvalidName):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "name is required", r)
	case errors.Is(err, family.ErrInvalidRegion):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid region", r)
	case errors.Is(err, family.ErrInviteNotFound):
		writeAPI(w, http.StatusNotFound, "FAMILY_NOT_FOUND", "invite not found", r)
	case errors.Is(err, family.ErrInviteExpired):
		writeAPI(w, http.StatusGone, "FAMILY_INVITE_EXPIRED", "invite expired", r)
	case errors.Is(err, family.ErrInviteUsedUp):
		writeAPI(w, http.StatusConflict, "FAMILY_INVITE_USED_UP", "invite used up", r)
	case errors.Is(err, family.ErrMemberLimit):
		writeAPI(w, http.StatusConflict, "FAMILY_MEMBER_LIMIT", "family member limit reached", r)
	case errors.Is(err, family.ErrAlreadyMember):
		writeAPI(w, http.StatusConflict, "FAMILY_ALREADY_MEMBER", "already a family member", r)
	case errors.Is(err, family.ErrInvalidRelation):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "relation is required", r)
	case errors.Is(err, family.ErrTransferTargetInvalid):
		writeAPI(w, http.StatusUnprocessableEntity, "FAMILY_TRANSFER_TARGET_INVALID", "invalid transfer target", r)
	case errors.Is(err, family.ErrTransferSelf):
		writeAPI(w, http.StatusUnprocessableEntity, "FAMILY_TRANSFER_SELF", "cannot transfer to self", r)
	case errors.Is(err, family.ErrAdminActive):
		writeAPI(w, http.StatusUnprocessableEntity, "FAMILY_ADMIN_ACTIVE", "admin is still active", r)
	case errors.Is(err, family.ErrTakeoverNotEligible):
		writeAPI(w, http.StatusForbidden, "FAMILY_TAKEOVER_NOT_ELIGIBLE", "not eligible for takeover", r)
	case errors.Is(err, family.ErrTakeoverAlreadyVoted):
		writeAPI(w, http.StatusConflict, "FAMILY_TAKEOVER_ALREADY_VOTED", "already voted on takeover", r)
	case errors.Is(err, family.ErrTakeoverNoActiveVote):
		writeAPI(w, http.StatusConflict, "FAMILY_TAKEOVER_NO_ACTIVE_VOTE", "no active takeover vote", r)
	case errors.Is(err, family.ErrInvalidChoice):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid ballot choice", r)
	case errors.Is(err, family.ErrTakeoverInProgress):
		writeAPI(w, http.StatusConflict, "FAMILY_TAKEOVER_IN_PROGRESS", "takeover already in progress", r)
	default:
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", err.Error(), r)
	}
}

func toFamilyDetailDTO(ctx context.Context, st store.Store, detail *store.FamilyDetail) familyDetailDTO {
	members := make([]familyMemberDTO, 0, len(detail.Members))
	for _, m := range detail.Members {
		members = append(members, familyMemberDTO{
			UserID:   m.UserID,
			Role:     string(m.Role),
			Nickname: m.Nickname,
			JoinedAt: m.JoinedAt.UTC().Format(time.RFC3339),
		})
	}

	babyItems := []any{}
	if st != nil {
		if babies, err := st.ListBabiesByFamily(ctx, detail.Family.ID); err == nil {
			babyItems = babiesToAny(babies)
		}
	}

	return familyDetailDTO{
		FamilyID: detail.Family.ID,
		Name:     detail.Family.Name,
		Role:     string(detail.Role),
		Members:  members,
		Babies:   babyItems,
	}
}

// decodeAPIResponse helps tests inspect JSON bodies.
func decodeAPIResponse(body []byte) (apiResponse, error) {
	var resp apiResponse
	err := json.Unmarshal(body, &resp)
	return resp, err
}
