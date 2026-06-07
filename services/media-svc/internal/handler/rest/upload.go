package rest

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/baobao/media-svc/internal/middleware"
	"github.com/baobao/media-svc/internal/model"
	"github.com/baobao/media-svc/internal/upload"
)

// UploadHandler serves upload init and complete endpoints.
type UploadHandler struct {
	svc *upload.Service
}

// NewUploadHandler creates upload REST handlers.
func NewUploadHandler(svc *upload.Service) *UploadHandler {
	return &UploadHandler{svc: svc}
}

type initRequest struct {
	Purpose  string `json:"purpose"`
	FamilyID string `json:"familyId"`
	Items    []struct {
		ClientRef string `json:"clientRef"`
		Kind      string `json:"kind"`
		Mime      string `json:"mime"`
		Size      int64  `json:"size"`
		SHA256    string `json:"sha256"`
	} `json:"items"`
}

type completeRequest struct {
	UploadID string `json:"uploadId"`
}

// Init handles POST /v1/uploads/init (operationId: uploadInit).
func (h *UploadHandler) Init(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	var req initRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, upload.ErrorCode(upload.ErrBadRequest), "invalid json body", r)
		return
	}

	region, ok := middleware.RegionFromContext(r.Context())
	if !ok {
		region = "cn"
	}

	items := make([]upload.InitItemInput, 0, len(req.Items))
	for _, item := range req.Items {
		items = append(items, upload.InitItemInput{
			ClientRef: item.ClientRef,
			Kind:      item.Kind,
			Mime:      item.Mime,
			Size:      item.Size,
			SHA256:    item.SHA256,
		})
	}

	out, err := h.svc.Init(r.Context(), upload.InitInput{
		UserID:   userID,
		Region:   region,
		Purpose:  model.Purpose(req.Purpose),
		FamilyID: req.FamilyID,
		Items:    items,
	})
	if err != nil {
		writeUploadError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

// Complete handles POST /v1/uploads/complete (operationId: uploadComplete).
func (h *UploadHandler) Complete(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	var req completeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, upload.ErrorCode(upload.ErrBadRequest), "invalid json body", r)
		return
	}

	out, err := h.svc.Complete(r.Context(), upload.CompleteInput{
		UserID:   userID,
		UploadID: req.UploadID,
	})
	if err != nil {
		writeUploadError(w, r, err)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "ok", r, out)
}

func writeUploadError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, upload.ErrUnauthorized):
		writeError(w, http.StatusUnauthorized, upload.ErrorCode(err), err.Error(), r)
	case errors.Is(err, upload.ErrForbidden):
		writeError(w, http.StatusForbidden, upload.ErrorCode(err), err.Error(), r)
	case errors.Is(err, upload.ErrNotFound):
		writeError(w, http.StatusNotFound, upload.ErrorCode(err), err.Error(), r)
	case errors.Is(err, upload.ErrBadRequest):
		writeError(w, http.StatusBadRequest, upload.ErrorCode(err), err.Error(), r)
	case errors.Is(err, upload.ErrSessionExpired), errors.Is(err, upload.ErrAlreadyCompleted):
		writeError(w, http.StatusUnprocessableEntity, upload.ErrorCode(err), err.Error(), r)
	default:
		writeError(w, http.StatusInternalServerError, upload.ErrorCode(err), "internal error", r)
	}
}
