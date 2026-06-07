package reconciliation

import (
	"context"
	"log/slog"
	"time"
)

// Cron periodically runs daily credit reconciliation.
type Cron struct {
	svc      *Service
	interval time.Duration
}

// NewCron creates a reconciliation cron.
func NewCron(svc *Service, interval time.Duration) *Cron {
	if interval <= 0 {
		interval = 24 * time.Hour
	}
	return &Cron{svc: svc, interval: interval}
}

// RunOnce executes reconciliation immediately.
func (c *Cron) RunOnce(ctx context.Context) (Result, error) {
	if c == nil || c.svc == nil {
		return Result{}, nil
	}
	return c.svc.RunDaily(ctx)
}

// Start runs the cron loop until ctx is cancelled.
func (c *Cron) Start(ctx context.Context) {
	if c == nil || c.svc == nil {
		return
	}
	go func() {
		c.runOnce(ctx)
		ticker := time.NewTicker(c.interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				c.runOnce(ctx)
			}
		}
	}()
}

func (c *Cron) runOnce(ctx context.Context) {
	result, err := c.svc.RunDaily(ctx)
	if err != nil {
		slog.Warn("credit reconciliation cron failed", "error", err)
		return
	}
	if result.HasDiscrepancy {
		slog.Warn("credit reconciliation cron completed with discrepancies",
			"run_id", result.Run.ID,
			"count", len(result.Discrepancies),
		)
		return
	}
	slog.Info("credit reconciliation cron ok",
		"run_id", result.Run.ID,
		"period_start", result.Run.PeriodStart.Format(time.RFC3339),
		"period_end", result.Run.PeriodEnd.Format(time.RFC3339),
	)
}
