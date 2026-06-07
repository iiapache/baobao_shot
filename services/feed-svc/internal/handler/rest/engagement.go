package rest

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/baobao/feed-svc/internal/engagement"
	"github.com/baobao/feed-svc/internal/middleware"
	"github.com/go-chi/chi/v5"
)

// EngagementHandler serves like and comment endpoints.
type EngagementHandler struct {
	svc *engagement.Service
}

// NewEngagementHandler creates engagement REST handlers.
func NewEngagementHandler(svc *engagement.Service) *EngagementHandler {
	return &EngagementHandler{svc: svc}
}

type createCommentRequest struct {
	Text     string  `json:"text"`
	ParentID *string `json:"parentId"`
}

// Like handles POST /v1/posts/{postId}/likes (operationId: postLike).
func (h *EngagementHandler) Like(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	postID := chi.URLParam(r, "postId")
	out, err := h.svc.Like(r.Context(), userID, postID)
	if err != nil {
		writeEngagementError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

// Unlike handles DELETE /v1/posts/{postId}/likes (operationId: postUnlike).
func (h *EngagementHandler) Unlike(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	postID := chi.URLParam(r, "postId")
	out, err := h.svc.Unlike(r.Context(), userID, postID)
	if err != nil {
		writeEngagementError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

// CreateComment handles POST /v1/posts/{postId}/comments (operationId: postCreateComment).
func (h *EngagementHandler) CreateComment(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	var req createCommentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, engagement.ErrorCode(engagement.ErrBadRequest), "invalid json body", r)
		return
	}

	region, _ := middleware.RegionFromContext(r.Context())
	out, err := h.svc.CreateComment(r.Context(), engagement.CreateCommentInput{
		UserID:   userID,
		Region:   region,
		PostID:   chi.URLParam(r, "postId"),
		Text:     req.Text,
		ParentID: req.ParentID,
	})
	if err != nil {
		writeEngagementError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

// DeleteComment handles DELETE /v1/posts/{postId}/comments/{commentId} (operationId: postDeleteComment).
func (h *EngagementHandler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	out, err := h.svc.DeleteComment(r.Context(), userID, chi.URLParam(r, "postId"), chi.URLParam(r, "commentId"))
	if err != nil {
		writeEngagementError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

func writeEngagementError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, engagement.ErrUnauthorized):
		writeError(w, http.StatusUnauthorized, engagement.ErrorCode(err), err.Error(), r)
	case errors.Is(err, engagement.ErrBadRequest):
		writeError(w, http.StatusBadRequest, engagement.ErrorCode(err), err.Error(), r)
	case errors.Is(err, engagement.ErrNotFound):
		writeError(w, http.StatusNotFound, engagement.ErrorCode(err), err.Error(), r)
	case errors.Is(err, engagement.ErrForbidden), errors.Is(err, engagement.ErrFamilyForbidden):
		writeError(w, http.StatusForbidden, engagement.ErrorCode(err), err.Error(), r)
	case errors.Is(err, engagement.ErrAuditRejected):
		writeError(w, http.StatusUnprocessableEntity, engagement.ErrorCode(err), err.Error(), r)
	default:
		writeError(w, http.StatusInternalServerError, engagement.ErrorCode(err), err.Error(), r)
	}
}
