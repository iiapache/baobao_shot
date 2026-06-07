package reconciliation

import (
	"context"
	"time"
)

// CostMeteringSource supplies model-side consumed credits for cross-service reconciliation.
type CostMeteringSource interface {
	CreditsConsumedInPeriod(ctx context.Context, start, end time.Time) (int64, error)
}

// StaticCostSource returns a fixed total (tests).
type StaticCostSource struct {
	Total int64
	Err   error
}

func (s StaticCostSource) CreditsConsumedInPeriod(_ context.Context, _, _ time.Time) (int64, error) {
	return s.Total, s.Err
}

// NopCostSource skips external model-cost comparison when ai-dispatch is not wired.
type NopCostSource struct{}

func (NopCostSource) CreditsConsumedInPeriod(_ context.Context, _, _ time.Time) (int64, error) {
	return 0, ErrCostSourceUnavailable
}

// ErrCostSourceUnavailable indicates external cost metering is not configured.
var ErrCostSourceUnavailable = errCostSourceUnavailable{}

type errCostSourceUnavailable struct{}

func (errCostSourceUnavailable) Error() string { return "cost metering source unavailable" }
