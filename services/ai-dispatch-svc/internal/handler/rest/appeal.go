package rest

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/auditclient"
	"github.com/baobao/ai-dispatch-svc/internal/middleware"
	"github.com/baobao/ai-dispatch-svc/internal/statemachine"
	"github.com/baobao/ai-dispatch-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// AppealHandler serves POST /v1/ai/tasks/{taskId}/appeal.
type AppealHandler struct {
	tasks store.TaskStore
	audit auditclient.Client
}

// NewAppealHandler creates task appeal REST handlers.
func NewAppealHandler(tasks store.TaskStore, audit auditclient.Client) *AppealHandler {
	return &AppealHandler{tasks: tasks, audit: audit}
}

type appealRequest struct {
	Reason string `json:"reason"`
}

type appealResponseData struct {
	TaskID   string `json:"taskId"`
	State    string `json:"state"`
	AppealID string `json:"appealId"`
}

// Appeal handles POST /v1/ai/tasks/{taskId}/appeal (operationId: aiAppealTask).
func (h *AppealHandler) Appeal(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}
	if h.tasks == nil || h.audit == nil {
		writeError(w, http.StatusServiceUnavailable, "COMMON_UPSTREAM", "appeal service unavailable", r)
		return
	}

	taskID := chi.URLParam(r, "taskId")
	if strings.TrimSpace(taskID) == "" {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "taskId required", r)
		return
	}

	var req appealRequest
	if err := decodeAppealRequest(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json", r)
		return
	}
	if strings.TrimSpace(req.Reason) == "" {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "reason required", r)
		return
	}

	task, err := h.tasks.GetByID(r.Context(), taskID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "AI_TASK_NOT_FOUND", "task not found", r)
			return
		}
		writeError(w, http.StatusInternalServerError, "COMMON_INTERNAL", "failed to load task", r)
		return
	}
	if task.UserID != userID {
		writeError(w, http.StatusForbidden, "AI_TASK_FORBIDDEN", "task access denied", r)
		return
	}
	if task.State != string(statemachine.StateRejected) {
		writeError(w, http.StatusConflict, "AI_APPEAL_NOT_ALLOWED", "appeal only allowed for rejected tasks", r)
		return
	}

	appealResp, err := h.audit.SubmitAppealForTask(r.Context(), auditclient.SubmitAppealRequest{
		TaskID: taskID,
		UserID: userID,
		Reason: req.Reason,
	})
	if err != nil {
		writeAppealError(w, err, r)
		return
	}

	now := time.Now().UTC()
	if _, err := statemachine.Transition(statemachine.StateRejected, statemachine.EventAppeal); err != nil {
		writeError(w, http.StatusInternalServerError, "COMMON_INTERNAL", "invalid state transition", r)
		return
	}
	if err := h.tasks.UpdateState(r.Context(), taskID, string(statemachine.StateAppealed), now); err != nil {
		writeError(w, http.StatusInternalServerError, "COMMON_INTERNAL", "failed to update task state", r)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, appealResponseData{
		TaskID:   taskID,
		State:    string(statemachine.StateAppealed),
		AppealID: appealResp.AppealID,
	})
}

func decodeAppealRequest(r *http.Request, req *appealRequest) error {
	defer r.Body.Close()
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		return err
	}
	if len(body) == 0 {
		return nil
	}
	return json.Unmarshal(body, req)
}

func writeAppealError(w http.ResponseWriter, err error, r *http.Request) {
	switch {
	case errors.Is(err, auditclient.ErrMissingReason):
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "reason required", r)
	case errors.Is(err, auditclient.ErrAuditJobNotFound):
		writeError(w, http.StatusNotFound, "AI_AUDIT_JOB_NOT_FOUND", "rejected audit job not found", r)
	case errors.Is(err, auditclient.ErrAppealDuplicate):
		writeError(w, http.StatusConflict, "AI_APPEAL_DUPLICATE", "appeal already submitted", r)
	case errors.Is(err, auditclient.ErrAppealNotAllowed):
		writeError(w, http.StatusConflict, "AI_APPEAL_NOT_ALLOWED", "appeal not allowed", r)
	default:
		writeError(w, http.StatusBadGateway, "COMMON_UPSTREAM", "audit service unavailable", r)
	}
}
