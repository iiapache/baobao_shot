package cnconfig

import (
	"context"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/filing"
	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/baobao/ai-dispatch-svc/internal/router"
	"github.com/baobao/ai-dispatch-svc/internal/worker"
)

// TestGhibliKidCNRoutesSeedream verifies 宫崎骏风 CN play selects SeedreamAdapter with valid filings.
func TestGhibliKidCNRoutesSeedream(t *testing.T) {
	t.Setenv("CN_ADAPTER_MOCK_MODE", "true")
	t.Setenv("BYTEDANCE_API_KEY", "test-bytedance-key")
	t.Setenv("BYTEDANCE_ENDPOINT", "http://mock-ai.example:8080")

	adapters := EnrichAdapters(worker.DefaultDevAdapters())
	modelRouter := worker.BuildDevRouter(adapters, filing.DevBindings())

	result, err := modelRouter.Route(router.RouteRequest{
		Region:     model.RegionCN,
		Style:      "ghibli_kid",
		Capability: model.CapabilityImageGen,
	})
	if err != nil {
		t.Fatalf("Route() error = %v", err)
	}
	if result.Adapter.Name() != "SeedreamAdapter" {
		t.Fatalf("adapter = %s, want SeedreamAdapter for ghibli_kid CN", result.Adapter.Name())
	}

	out, err := result.Adapter.Invoke(context.Background(), adapter.InvokeRequest{
		Style:      "ghibli_kid",
		Capability: model.CapabilityImageGen,
		Region:     model.RegionCN,
		Input:      model.TaskInput{ObjectKey: "ai-tmp/usr_1/kid.jpg"},
	})
	if err != nil {
		t.Fatalf("Invoke() error = %v", err)
	}
	if out.ObjectKey == "" {
		t.Fatal("expected output object key from Seedream mock path")
	}
}
