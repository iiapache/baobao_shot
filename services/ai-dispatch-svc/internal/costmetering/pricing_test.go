package costmetering

import (
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

func TestEstimateVendorCostCNY_Image(t *testing.T) {
	got := EstimateVendorCostCNY(model.CapabilityImageGen, 8)
	if got != 0.75 {
		t.Fatalf("8 credit image cost = %v, want 0.75", got)
	}
}

func TestEstimateVendorCostCNY_Video(t *testing.T) {
	got := EstimateVendorCostCNY(model.CapabilityVideoGen, 60)
	if got != 4.85 {
		t.Fatalf("60 credit video cost = %v, want 4.85", got)
	}
}

func TestWeekStart(t *testing.T) {
	start := WeekStart(timeMustParse("2026-06-06T12:00:00Z"))
	want := timeMustParse("2026-06-01T00:00:00Z")
	if !start.Equal(want) {
		t.Fatalf("WeekStart = %v, want %v", start, want)
	}
}

func timeMustParse(raw string) time.Time {
	t, err := time.Parse(time.RFC3339, raw)
	if err != nil {
		panic(err)
	}
	return t.UTC()
}
