package costmetering

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestService_ReportInvocationAndTaskCosts(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	task := &model.Task{
		ID:          "tsk_img",
		UserID:      "usr_1",
		Region:      model.RegionCN,
		Style:       "ghibli_kid",
		Capability:  model.CapabilityImageGen,
		CostCredits: 8,
	}
	stub := &adapter.StubAdapter{
		AdapterName:   "SeedreamAdapter",
		AdapterRegion: model.RegionCN,
		Capabilities:  []model.Capability{model.CapabilityImageGen},
		UnitCost:      8,
	}

	at := timeMustParse("2026-06-03T10:00:00Z")
	if err := svc.ReportInvocation(context.Background(), ReportRequest{
		Task: task, Vendor: stub.Name(), Adapter: stub,
		InvokeReq: adapter.InvokeRequest{Capability: model.CapabilityImageGen},
		LatencyMs: 1200, Retry: 0, ReportedAt: at,
	}); err != nil {
		t.Fatalf("ReportInvocation() error = %v", err)
	}

	records, err := svc.TaskCosts(context.Background(), task.ID)
	if err != nil {
		t.Fatalf("TaskCosts() error = %v", err)
	}
	if len(records) != 1 {
		t.Fatalf("records = %d, want 1", len(records))
	}
	if records[0].VendorCostCNY != 0.75 {
		t.Fatalf("VendorCostCNY = %v, want 0.75", records[0].VendorCostCNY)
	}
}

func TestService_WeeklyReport_ImageAndVideo(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	weekStart := timeMustParse("2026-06-02T00:00:00Z")

	imageTask := &model.Task{
		ID: "tsk_img_w", UserID: "usr_1", Region: model.RegionCN,
		Style: "ghibli_kid", Capability: model.CapabilityImageGen, CostCredits: 8,
	}
	videoTask := &model.Task{
		ID: "tsk_vid_w", UserID: "usr_2", Region: model.RegionCN,
		Style: "baby_dance", Capability: model.CapabilityVideoGen, CostCredits: 60,
	}
	imageAdapter := &adapter.StubAdapter{
		AdapterName: "SeedreamAdapter", AdapterRegion: model.RegionCN,
		Capabilities: []model.Capability{model.CapabilityImageGen},
		UnitCost:     8,
	}
	videoAdapter := &adapter.StubAdapter{
		AdapterName: "SeedanceAdapter", AdapterRegion: model.RegionCN,
		Capabilities: []model.Capability{model.CapabilityVideoGen},
		UnitCost:     60,
	}

	mustReport := func(task *model.Task, vendor string, a adapter.ModelAdapter, req adapter.InvokeRequest, at time.Time) {
		t.Helper()
		if err := svc.ReportInvocation(context.Background(), ReportRequest{
			Task: task, Vendor: vendor, Adapter: a, InvokeReq: req,
			LatencyMs: 1000, ReportedAt: at,
		}); err != nil {
			t.Fatalf("ReportInvocation() error = %v", err)
		}
	}

	mustReport(imageTask, imageAdapter.Name(), imageAdapter,
		adapter.InvokeRequest{Capability: model.CapabilityImageGen},
		weekStart.Add(24*time.Hour))
	mustReport(videoTask, videoAdapter.Name(), videoAdapter,
		adapter.InvokeRequest{Capability: model.CapabilityVideoGen, DurationSeconds: 5},
		weekStart.Add(48*time.Hour))

	report, err := svc.WeeklyReport(context.Background(), weekStart)
	if err != nil {
		t.Fatalf("WeeklyReport() error = %v", err)
	}
	if report.TotalRecords != 2 {
		t.Fatalf("TotalRecords = %d, want 2", report.TotalRecords)
	}
	wantCost := roundCNY(0.75 + 4.85)
	if report.TotalVendorCostCNY != wantCost {
		t.Fatalf("TotalVendorCostCNY = %v, want %v", report.TotalVendorCostCNY, wantCost)
	}
	if len(report.ByCapability) != 2 {
		t.Fatalf("ByCapability = %d groups, want 2", len(report.ByCapability))
	}
}
