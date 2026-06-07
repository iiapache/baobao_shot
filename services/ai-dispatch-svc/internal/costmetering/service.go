package costmetering

import (
	"context"
	"fmt"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// ReportRequest carries invocation context for cost metering.
type ReportRequest struct {
	Task       *model.Task
	Vendor     string
	Adapter    adapter.ModelAdapter
	InvokeReq  adapter.InvokeRequest
	LatencyMs  int64
	Retry      int
	ReportedAt time.Time
}

// Service records vendor costs and builds weekly reconciliation reports.
type Service struct {
	store Store
}

// NewService creates a cost metering service.
func NewService(store Store) *Service {
	return &Service{store: store}
}

// ReportInvocation persists a successful model invocation cost (design-backend §5.2).
func (s *Service) ReportInvocation(ctx context.Context, req ReportRequest) error {
	if s == nil || s.store == nil {
		return nil
	}
	if req.Task == nil || req.Task.ID == "" {
		return fmt.Errorf("task required")
	}

	at := req.ReportedAt
	if at.IsZero() {
		at = time.Now().UTC()
	}

	credits := req.Task.CostCredits
	if req.Adapter != nil {
		credits = req.Adapter.Cost(req.InvokeReq)
	}
	if credits <= 0 {
		credits = req.Task.CostCredits
	}

	record := &Record{
		ID:            fmt.Sprintf("%s:%d:%d", req.Task.ID, req.Retry, at.UnixNano()),
		TaskID:        req.Task.ID,
		UserID:        req.Task.UserID,
		Region:        req.Task.Region,
		Style:         req.Task.Style,
		Capability:    req.Task.Capability,
		Vendor:        req.Vendor,
		CostCredits:   credits,
		VendorCostCNY: EstimateVendorCostCNY(req.Task.Capability, credits),
		LatencyMs:     req.LatencyMs,
		Retry:         req.Retry,
		ReportedAt:    at,
	}
	return s.store.Insert(ctx, record)
}

// TaskCosts returns all cost records for a single task.
func (s *Service) TaskCosts(ctx context.Context, taskID string) ([]Record, error) {
	if s == nil || s.store == nil {
		return nil, fmt.Errorf("cost metering unavailable")
	}
	return s.store.ListByTaskID(ctx, taskID)
}

// CapabilitySummary aggregates cost metrics for one capability bucket.
type CapabilitySummary struct {
	Capability         string  `json:"capability"`
	TaskCount          int     `json:"taskCount"`
	TotalCredits       int     `json:"totalCredits"`
	TotalVendorCostCNY float64 `json:"totalVendorCostCNY"`
	AvgUnitCostCNY     float64 `json:"avgUnitCostCNY"`
}

// WeeklyReport is the reconciliation snapshot for a calendar week (Mon 00:00 UTC).
type WeeklyReport struct {
	WeekStart          time.Time           `json:"weekStart"`
	WeekEnd            time.Time           `json:"weekEnd"`
	TotalRecords       int                 `json:"totalRecords"`
	TotalCredits       int                 `json:"totalCredits"`
	TotalVendorCostCNY float64             `json:"totalVendorCostCNY"`
	ByCapability       []CapabilitySummary `json:"byCapability"`
}

// WeekStart returns Monday 00:00 UTC for the week containing t.
func WeekStart(t time.Time) time.Time {
	t = t.UTC()
	weekday := int(t.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	start := time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -(weekday - 1))
	return start
}

// WeeklyReport aggregates cost records for the week starting at weekStart.
func (s *Service) WeeklyReport(ctx context.Context, weekStart time.Time) (*WeeklyReport, error) {
	if s == nil || s.store == nil {
		return nil, fmt.Errorf("cost metering unavailable")
	}
	start := WeekStart(weekStart)
	end := start.AddDate(0, 0, 7)

	records, err := s.store.ListByTimeRange(ctx, start, end)
	if err != nil {
		return nil, err
	}

	byCap := make(map[model.Capability]*CapabilitySummary)
	var totalCredits int
	var totalCost float64
	for _, rec := range records {
		totalCredits += rec.CostCredits
		totalCost += rec.VendorCostCNY
		sum, ok := byCap[rec.Capability]
		if !ok {
			sum = &CapabilitySummary{Capability: string(rec.Capability)}
			byCap[rec.Capability] = sum
		}
		sum.TaskCount++
		sum.TotalCredits += rec.CostCredits
		sum.TotalVendorCostCNY = roundCNY(sum.TotalVendorCostCNY + rec.VendorCostCNY)
	}

	summaries := make([]CapabilitySummary, 0, len(byCap))
	for _, sum := range byCap {
		if sum.TaskCount > 0 {
			sum.AvgUnitCostCNY = roundCNY(sum.TotalVendorCostCNY / float64(sum.TaskCount))
		}
		summaries = append(summaries, *sum)
	}

	return &WeeklyReport{
		WeekStart:          start,
		WeekEnd:            end,
		TotalRecords:       len(records),
		TotalCredits:       totalCredits,
		TotalVendorCostCNY: roundCNY(totalCost),
		ByCapability:       summaries,
	}, nil
}
