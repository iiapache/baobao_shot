package rest

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/baobao/feed-svc/internal/middleware"
	"github.com/baobao/feed-svc/internal/post"
	"github.com/go-chi/chi/v5"
)

// PostHandler serves post publish endpoints.
type PostHandler struct {
	svc *post.Service
}

// NewPostHandler creates post REST handlers.
func NewPostHandler(svc *post.Service) *PostHandler {
	return &PostHandler{svc: svc}
}

type createPostRequest struct {
	FamilyID   string `json:"familyId"`
	BabyIDs    []string `json:"babyIds"`
	Caption    string `json:"caption"`
	Visibility string `json:"visibility"`
	Items      []struct {
		Kind         string `json:"kind"`
		ObjectKey    string `json:"objectKey"`
		Mime         string `json:"mime"`
		Width        int    `json:"width"`
		Height       int    `json:"height"`
		Duration     *int   `json:"duration"`
		DeepSynth    bool   `json:"deepSynth"`
		ThumbnailKey *string `json:"thumbnailKey"`
	} `json:"items"`
}

// Create handles POST /v1/posts (operationId: postCreate).
func (h *PostHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	var req createPostRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, post.ErrorCode(post.ErrBadRequest), "invalid json body", r)
		return
	}

	region, _ := middleware.RegionFromContext(r.Context())

	items := make([]post.CreateItemInput, 0, len(req.Items))
	for _, item := range req.Items {
		items = append(items, post.CreateItemInput{
			Kind:         item.Kind,
			ObjectKey:    item.ObjectKey,
			Mime:         item.Mime,
			Width:        item.Width,
			Height:       item.Height,
			Duration:     item.Duration,
			DeepSynth:    item.DeepSynth,
			ThumbnailKey: item.ThumbnailKey,
		})
	}

	out, err := h.svc.Create(r.Context(), post.CreateInput{
		UserID:     userID,
		Region:     region,
		FamilyID:   req.FamilyID,
		BabyIDs:    req.BabyIDs,
		Caption:    req.Caption,
		Visibility: req.Visibility,
		Items:      items,
	})
	if err != nil {
		writePostError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

// Delete handles DELETE /v1/posts/{postId} (operationId: postDelete).
func (h *PostHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	postID := chi.URLParam(r, "postId")
	region, _ := middleware.RegionFromContext(r.Context())

	out, err := h.svc.Delete(r.Context(), userID, postID, region)
	if err != nil {
		writePostError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

func writePostError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, post.ErrUnauthorized):
		writeError(w, http.StatusUnauthorized, post.ErrorCode(err), err.Error(), r)
	case errors.Is(err, post.ErrBadRequest), errors.Is(err, post.ErrItemLimit):
		writeError(w, http.StatusUnprocessableEntity, post.ErrorCode(err), err.Error(), r)
	case errors.Is(err, post.ErrAuditRejected):
		writeError(w, http.StatusUnprocessableEntity, post.ErrorCode(err), err.Error(), r)
	case errors.Is(err, post.ErrRateLimited):
		writeError(w, http.StatusTooManyRequests, post.ErrorCode(err), err.Error(), r)
	case errors.Is(err, post.ErrFamilyForbidden), errors.Is(err, post.ErrForbidden):
		writeError(w, http.StatusForbidden, post.ErrorCode(err), err.Error(), r)
	case errors.Is(err, post.ErrNotFound):
		writeError(w, http.StatusNotFound, post.ErrorCode(err), err.Error(), r)
	default:
		writeError(w, http.StatusInternalServerError, post.ErrorCode(err), err.Error(), r)
	}
}
