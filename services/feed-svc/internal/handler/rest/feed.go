package rest

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/baobao/feed-svc/internal/feed"
	"github.com/baobao/feed-svc/internal/middleware"
	"github.com/baobao/feed-svc/internal/store"
)

// FeedHandler serves family feed list endpoints.
type FeedHandler struct {
	svc *feed.Service
}

// NewFeedHandler creates feed REST handlers.
func NewFeedHandler(svc *feed.Service) *FeedHandler {
	return &FeedHandler{svc: svc}
}

// ListFamily handles GET /v1/feeds/family (operationId: feedListFamily).
func (h *FeedHandler) ListFamily(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	familyID := r.URL.Query().Get("familyId")
	cursor := r.URL.Query().Get("cursor")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))

	out, err := h.svc.List(r.Context(), feed.ListInput{
		UserID:   userID,
		FamilyID: familyID,
		Cursor:   cursor,
		Limit:    limit,
	})
	if err != nil {
		writeFeedError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

func writeFeedError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, feed.ErrUnauthorized):
		writeError(w, http.StatusUnauthorized, feed.ErrorCode(err), err.Error(), r)
	case errors.Is(err, feed.ErrBadRequest):
		writeError(w, http.StatusBadRequest, feed.ErrorCode(err), err.Error(), r)
	case errors.Is(err, feed.ErrFamilyForbidden):
		writeError(w, http.StatusForbidden, feed.ErrorCode(err), err.Error(), r)
	case errors.Is(err, store.ErrInvalidCursor):
		writeError(w, http.StatusBadRequest, feed.ErrorCode(feed.ErrInvalidCursor), "invalid cursor", r)
	default:
		writeError(w, http.StatusInternalServerError, feed.ErrorCode(err), err.Error(), r)
	}
}
