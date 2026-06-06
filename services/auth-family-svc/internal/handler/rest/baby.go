package rest

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/baobao/auth-family-svc/internal/avatar"
	"github.com/baobao/auth-family-svc/internal/baby"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// NewBabyHandler creates baby REST handlers.
func NewBabyHandler(s store.Store, avatars avatar.Storage) *BabyHandler {
	if avatars == nil {
		avatars = avatar.NewLocalStorage("", "")
	}
	return &BabyHandler{svc: baby.NewService(s), avatars: avatars}
}

// BabyHandler serves baby profile endpoints.
type BabyHandler struct {
	svc     *baby.Service
	avatars avatar.Storage
}

type createBabyRequest struct {
	Name        string   `json:"name"`
	Birthday    string   `json:"birthday"`
	Gender      string   `json:"gender"`
	FullName    *string  `json:"fullName"`
	BirthTime   *string  `json:"birthTime"`
	BirthWeight *float64 `json:"birthWeight"`
	BirthLength *float64 `json:"birthLength"`
	BirthPlace  *string  `json:"birthPlace"`
}

type updateBabyRequest struct {
	Name        *string  `json:"name"`
	Birthday    *string  `json:"birthday"`
	Gender      *string  `json:"gender"`
	FullName    *string  `json:"fullName"`
	BirthTime   *string  `json:"birthTime"`
	BirthWeight *float64 `json:"birthWeight"`
	BirthLength *float64 `json:"birthLength"`
	BirthPlace  *string  `json:"birthPlace"`
}

type babyDTO struct {
	BabyID      string   `json:"babyId"`
	FamilyID    string   `json:"familyId,omitempty"`
	Name        string   `json:"name"`
	Birthday    string   `json:"birthday"`
	Gender      string   `json:"gender"`
	FullName    *string  `json:"fullName,omitempty"`
	BirthTime   *string  `json:"birthTime,omitempty"`
	BirthWeight *float64 `json:"birthWeight,omitempty"`
	BirthLength *float64 `json:"birthLength,omitempty"`
	BirthPlace  *string  `json:"birthPlace,omitempty"`
	Timezone    string   `json:"timezone,omitempty"`
	AvatarURL   *string  `json:"avatarUrl,omitempty"`
}

// Service exposes baby service for middleware wiring.
func (h *BabyHandler) Service() *baby.Service {
	return h.svc
}

// Create handles POST /v1/families/{familyId}/babies.
func (h *BabyHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")

	var req createBabyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}

	created, err := h.svc.Create(r.Context(), baby.CreateInput{
		FamilyID:    familyID,
		UserID:      userID,
		Name:        req.Name,
		FullName:    req.FullName,
		Gender:      req.Gender,
		Birthday:    req.Birthday,
		BirthTime:   req.BirthTime,
		BirthWeight: req.BirthWeight,
		BirthLength: req.BirthLength,
		BirthPlace:  req.BirthPlace,
		DeviceTZ:    deviceTimezone(r),
	})
	if err != nil {
		mapBabyError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, toBabyDTO(created))
}

// ListByFamily handles GET /v1/families/{familyId}/babies.
func (h *BabyHandler) ListByFamily(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	familyID := chi.URLParam(r, "familyId")

	items, err := h.svc.ListByFamily(r.Context(), familyID, userID)
	if err != nil {
		mapBabyError(w, r, err)
		return
	}

	dtos := make([]babyDTO, 0, len(items))
	for i := range items {
		dtos = append(dtos, toBabySummaryDTO(&items[i]))
	}
	writeAPI(w, http.StatusOK, "OK", "", r, map[string]any{"items": dtos})
}

// Get handles GET /v1/babies/{babyId}.
func (h *BabyHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	babyID := chi.URLParam(r, "babyId")

	item, err := h.svc.Get(r.Context(), babyID, userID)
	if err != nil {
		mapBabyError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, toBabyDTO(item))
}

// Update handles PATCH /v1/babies/{babyId}.
func (h *BabyHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	babyID := chi.URLParam(r, "babyId")

	var req updateBabyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json body", r)
		return
	}

	updated, err := h.svc.Update(r.Context(), baby.UpdateInput{
		BabyID:      babyID,
		UserID:      userID,
		Name:        req.Name,
		FullName:    req.FullName,
		Gender:      req.Gender,
		Birthday:    req.Birthday,
		BirthTime:   req.BirthTime,
		BirthWeight: req.BirthWeight,
		BirthLength: req.BirthLength,
		BirthPlace:  req.BirthPlace,
		DeviceTZ:    deviceTimezone(r),
	})
	if err != nil {
		mapBabyError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, toBabyDTO(updated))
}

// Delete handles DELETE /v1/babies/{babyId}.
func (h *BabyHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	babyID := chi.URLParam(r, "babyId")

	if err := h.svc.Delete(r.Context(), babyID, userID); err != nil {
		mapBabyError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, map[string]string{"babyId": babyID})
}

// UploadAvatar handles POST /v1/babies/{babyId}/avatar.
func (h *BabyHandler) UploadAvatar(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	babyID := chi.URLParam(r, "babyId")

	r.Body = http.MaxBytesReader(w, r.Body, baby.MaxAvatarBytes)
	defer r.Body.Close()

	data, err := io.ReadAll(r.Body)
	if err != nil {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid avatar payload", r)
		return
	}
	if len(data) == 0 {
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "avatar file required", r)
		return
	}

	contentType := r.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "image/jpeg"
	}

	url, err := h.avatars.Save(r.Context(), babyID, data, contentType)
	if err != nil {
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", "avatar upload failed", r)
		return
	}

	updated, err := h.svc.SetAvatarURL(r.Context(), babyID, userID, url)
	if err != nil {
		mapBabyError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, map[string]any{
		"babyId":    updated.ID,
		"avatarUrl": updated.AvatarURL,
	})
}

func mapBabyError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, baby.ErrNotFound):
		writeAPI(w, http.StatusNotFound, "BABY_NOT_FOUND", "baby not found", r)
	case errors.Is(err, baby.ErrNotMember):
		writeAPI(w, http.StatusNotFound, "FAMILY_NOT_FOUND", "family not found", r)
	case errors.Is(err, baby.ErrInvalidName):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "name is required", r)
	case errors.Is(err, baby.ErrInvalidGender):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid gender", r)
	case errors.Is(err, baby.ErrInvalidBirth):
		writeAPI(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid birth date or time", r)
	default:
		writeAPI(w, http.StatusInternalServerError, "SYS_INTERNAL", err.Error(), r)
	}
}

func deviceTimezone(r *http.Request) string {
	if tz := strings.TrimSpace(r.Header.Get("X-Device-Timezone")); tz != "" {
		return tz
	}
	return strings.TrimSpace(r.Header.Get("X-Timezone"))
}

func toBabySummaryDTO(b *model.Baby) babyDTO {
	return babyDTO{
		BabyID:   b.ID,
		Name:     b.Name,
		Birthday: b.BirthDate.Format("2006-01-02"),
		Gender:   string(b.Gender),
	}
}

func toBabyDTO(b *model.Baby) babyDTO {
	dto := toBabySummaryDTO(b)
	dto.FamilyID = b.FamilyID
	dto.FullName = b.FullName
	dto.BirthWeight = b.BirthWeight
	dto.BirthLength = b.BirthLength
	dto.BirthPlace = b.BirthPlace
	dto.Timezone = b.Timezone
	dto.AvatarURL = b.AvatarURL
	if b.BirthTime != nil {
		s := b.BirthTime.Format("15:04")
		dto.BirthTime = &s
	}
	return dto
}

func babiesToAny(items []model.Baby) []any {
	out := make([]any, 0, len(items))
	for i := range items {
		out = append(out, toBabySummaryDTO(&items[i]))
	}
	return out
}
