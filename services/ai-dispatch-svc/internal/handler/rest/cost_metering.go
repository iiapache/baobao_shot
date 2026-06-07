package rest

import (
	"net/http"
	"strings"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/costmetering"
	"github.com/go-chi/chi/v5"
)

// CostMeteringHandler serves internal cost metering APIs.
type CostMeteringHandler struct {
	svc *costmetering.Service
}

// NewCostMeteringHandler creates internal cost metering REST handlers.
func NewCostMeteringHandler(svc *costmetering.Service) *CostMeteringHandler {
	return &CostMeteringHandler{svc: svc}
}

type taskCostsResponse struct {
	TaskID  string              `json:"taskId"`
	Records []costmetering.Record `json:"records"`
	TotalVendorCostCNY float64  `json:"totalVendorCostCNY"`
}

// TaskCosts handles GET /internal/v1/cost-metering/tasks/{taskId}.
func (h *CostMeteringHandler) TaskCosts(w http.ResponseWriter, r *http.Request) {
	if h.svc == nil {
		writeError(w, http.StatusServiceUnavailable, "COMMON_UPSTREAM", "cost metering unavailable", r)
		return
	}
	taskID := strings.TrimSpace(chi.URLParam(r, "taskId"))
	if taskID == "" {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "taskId required", r)
		return
	}

	records, err := h.svc.TaskCosts(r.Context(), taskID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "COMMON_INTERNAL", "failed to load cost records", r)
		return
	}

	var total float64
	for _, rec := range records {
		total += rec.VendorCostCNY
	}
	writeJSON(w, http.StatusOK, taskCostsResponse{
		TaskID:             taskID,
		Records:            records,
		TotalVendorCostCNY: costmetering.RoundCNY(total),
	})
}

// WeeklyReport handles GET /internal/v1/cost-metering/weekly-report.
func (h *CostMeteringHandler) WeeklyReport(w http.ResponseWriter, r *http.Request) {
	if h.svc == nil {
		writeError(w, http.StatusServiceUnavailable, "COMMON_UPSTREAM", "cost metering unavailable", r)
		return
	}

	weekStart := costmetering.WeekStart(time.Now().UTC())
	if raw := strings.TrimSpace(r.URL.Query().Get("weekStart")); raw != "" {
		parsed, err := time.Parse(time.RFC3339, raw)
		if err != nil {
			writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "weekStart must be RFC3339", r)
			return
		}
		weekStart = costmetering.WeekStart(parsed)
	}

	report, err := h.svc.WeeklyReport(r.Context(), weekStart)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "COMMON_INTERNAL", "failed to build weekly report", r)
		return
	}
	writeJSON(w, http.StatusOK, report)
}
