package rest

import (
	"errors"
	"net/http"

	"github.com/baobao/audit-svc/internal/audit"
	"github.com/baobao/audit-svc/internal/model"
)

// AuditHandler exposes dev-friendly REST mirrors of sync RPC.
type AuditHandler struct {
	service *audit.Service
}

// NewAuditHandler creates REST handlers for audit operations.
func NewAuditHandler(service *audit.Service) *AuditHandler {
	return &AuditHandler{service: service}
}

type syncAuditRequest struct {
	Kind      string `json:"kind"`
	TargetRef string `json:"targetRef"`
	Region    string `json:"region"`
	MediaType string `json:"mediaType,omitempty"`
	ObjectKey string `json:"objectKey,omitempty"`
	Text      string `json:"text,omitempty"`
}

type syncAuditResponse struct {
	JobID   string   `json:"jobId"`
	Status  string   `json:"status"`
	Result  string   `json:"result"`
	Reasons []string `json:"reasons"`
	Vendor  string   `json:"vendor"`
}

type submitAppealRequest struct {
	AuditJobID string `json:"auditJobId"`
	TargetRef  string `json:"targetRef"`
	UserID     string `json:"userId"`
	Reason     string `json:"reason"`
}

type submitAppealResponse struct {
	AppealID string `json:"appealId"`
	Status   string `json:"status"`
}

// Sync handles POST /v1/audit/sync.
func (h *AuditHandler) Sync(w http.ResponseWriter, r *http.Request) {
	var req syncAuditRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	job, err := h.service.SyncAudit(r.Context(), model.AuditKind(req.Kind), audit.SyncRequest{
		TargetRef: req.TargetRef,
		Region:    req.Region,
		MediaType: req.MediaType,
		ObjectKey: req.ObjectKey,
		Text:      req.Text,
	})
	if err != nil {
		writeAuditError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, syncAuditResponse{
		JobID:   job.ID,
		Status:  string(job.Status),
		Result:  job.Result,
		Reasons: job.Reasons,
		Vendor:  job.Vendor,
	})
}

// SubmitAppeal handles POST /v1/appeals.
func (h *AuditHandler) SubmitAppeal(w http.ResponseWriter, r *http.Request) {
	var req submitAppealRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	var (
		appeal *model.Appeal
		err    error
	)
	switch {
	case req.AuditJobID != "":
		appeal, err = h.service.SubmitAppeal(r.Context(), req.AuditJobID, req.UserID, req.Reason)
	case req.TargetRef != "":
		appeal, err = h.service.SubmitAppealForTask(r.Context(), req.TargetRef, req.UserID, req.Reason)
	default:
		writeError(w, http.StatusBadRequest, "auditJobId or targetRef required")
		return
	}
	if err != nil {
		writeAuditError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, submitAppealResponse{
		AppealID: appeal.ID,
		Status:   string(appeal.Status),
	})
}

func writeAuditError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, audit.ErrInvalidKind),
		errors.Is(err, audit.ErrInvalidRegion),
		errors.Is(err, audit.ErrMissingTargetRef),
		errors.Is(err, audit.ErrMissingAppealText):
		writeError(w, http.StatusBadRequest, err.Error())
	case errors.Is(err, audit.ErrAppealNotAllowed),
		errors.Is(err, audit.ErrAppealDuplicate):
		writeError(w, http.StatusConflict, err.Error())
	case errors.Is(err, audit.ErrAuditJobNotFound):
		writeError(w, http.StatusNotFound, err.Error())
	default:
		writeError(w, http.StatusInternalServerError, err.Error())
	}
}
