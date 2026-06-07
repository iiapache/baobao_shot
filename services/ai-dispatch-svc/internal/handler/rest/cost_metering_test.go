package rest

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/config"
	"github.com/baobao/ai-dispatch-svc/internal/costmetering"
	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/go-chi/chi/v5"
)

func TestCostMeteringHandler_TaskCosts(t *testing.T) {
	store := costmetering.NewMemoryStore()
	svc := costmetering.NewService(store)
	handler := NewCostMeteringHandler(svc)

	task := &model.Task{
		ID: "tsk_api", UserID: "usr_1", Region: model.RegionCN,
		Style: "ghibli_kid", Capability: model.CapabilityImageGen, CostCredits: 8,
	}
	stub := &adapter.StubAdapter{
		AdapterName: "SeedreamAdapter", AdapterRegion: model.RegionCN,
		Capabilities: []model.Capability{model.CapabilityImageGen}, UnitCost: 8,
	}
	if err := svc.ReportInvocation(context.Background(), costmetering.ReportRequest{
		Task: task, Vendor: stub.Name(), Adapter: stub,
		InvokeReq: adapter.InvokeRequest{Capability: model.CapabilityImageGen},
		ReportedAt: time.Now().UTC(),
	}); err != nil {
		t.Fatalf("ReportInvocation() error = %v", err)
	}

	r := chi.NewRouter()
	r.Get("/internal/v1/cost-metering/tasks/{taskId}", handler.TaskCosts)
	req := httptest.NewRequest(http.MethodGet, "/internal/v1/cost-metering/tasks/tsk_api", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if !strings.Contains(body, `"taskId":"tsk_api"`) || !strings.Contains(body, `"vendorCostCNY":0.75`) {
		t.Fatalf("body = %s", body)
	}
}

func TestCostMeteringHandler_WeeklyReport(t *testing.T) {
	store := costmetering.NewMemoryStore()
	svc := costmetering.NewService(store)
	handler := NewCostMeteringHandler(svc)

	weekStart := costmetering.WeekStart(time.Date(2026, 6, 3, 0, 0, 0, 0, time.UTC))
	task := &model.Task{
		ID: "tsk_week", UserID: "usr_1", Region: model.RegionCN,
		Style: "ghibli_kid", Capability: model.CapabilityImageGen, CostCredits: 8,
	}
	stub := &adapter.StubAdapter{
		AdapterName: "SeedreamAdapter", AdapterRegion: model.RegionCN,
		Capabilities: []model.Capability{model.CapabilityImageGen}, UnitCost: 8,
	}
	if err := svc.ReportInvocation(context.Background(), costmetering.ReportRequest{
		Task: task, Vendor: stub.Name(), Adapter: stub,
		InvokeReq: adapter.InvokeRequest{Capability: model.CapabilityImageGen},
		ReportedAt: weekStart.Add(12 * time.Hour),
	}); err != nil {
		t.Fatalf("ReportInvocation() error = %v", err)
	}

	r := chi.NewRouter()
	r.Get("/internal/v1/cost-metering/weekly-report", handler.WeeklyReport)
	req := httptest.NewRequest(http.MethodGet, "/internal/v1/cost-metering/weekly-report?weekStart="+weekStart.Format(time.RFC3339), nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if !strings.Contains(body, `"totalRecords":1`) || !strings.Contains(body, `"totalVendorCostCNY":0.75`) {
		t.Fatalf("body = %s", body)
	}
}

func TestRouter_CostMeteringRoutes(t *testing.T) {
	store := costmetering.NewMemoryStore()
	svc := costmetering.NewService(store)
	handler := NewRouter(&config.Config{ServiceName: "ai-dispatch-svc"}, RouterDeps{
		CostMetering: svc,
	})

	req := httptest.NewRequest(http.MethodGet, "/internal/v1/cost-metering/weekly-report", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
}
