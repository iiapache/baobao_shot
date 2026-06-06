package rest

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/baobao/auth-family-svc/internal/family"
	"github.com/go-chi/chi/v5"
)

type invitationResponseDTO struct {
	Code      string           `json:"code"`
	ExpireAt  string           `json:"expireAt"`
	MaxUses   int              `json:"maxUses"`
	UsedCount int              `json:"usedCount"`
	QRPayload family.QRPayload `json:"qrPayload"`
}

type joinInvitationRequest struct {
	Relation string `json:"relation"`
	Nickname string `json:"nickname"`
}

type joinInvitationResponseDTO struct {
	FamilyID string `json:"familyId"`
	Role     string `json:"role"`
	JoinedAt string `json:"joinedAt"`
}

// CreateInvitation handles POST /v1/families/{familyId}/invitations.
func (h *FamilyHandler) CreateInvitation(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")

	invite, payload, err := h.svc.CreateInvitation(r.Context(), familyID, userID)
	if err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, invitationResponseDTO{
		Code:      invite.Code,
		ExpireAt:  invite.ExpireAt.UTC().Format(time.RFC3339),
		MaxUses:   invite.MaxUses,
		UsedCount: invite.UsedCount,
		QRPayload: payload,
	})
}

// RevokeInvitation handles DELETE /v1/families/{familyId}/invitations/{code}.
func (h *FamilyHandler) RevokeInvitation(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")
	code := chi.URLParam(r, "code")

	if err := h.svc.RevokeInvitation(r.Context(), familyID, userID, code); err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, map[string]string{
		"code": code,
	})
}

// JoinInvitation handles POST /v1/invitations/{code}/join.
func (h *FamilyHandler) JoinInvitation(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	code := chi.URLParam(r, "code")

	var req joinInvitationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}

	result, err := h.svc.JoinViaInvitation(r.Context(), code, userID, req.Relation, req.Nickname)
	if err != nil {
		mapFamilyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, joinInvitationResponseDTO{
		FamilyID: result.FamilyID,
		Role:     string(result.Role),
		JoinedAt: result.JoinedAt.UTC().Format(time.RFC3339),
	})
}
