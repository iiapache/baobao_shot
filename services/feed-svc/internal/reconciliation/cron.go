package reconciliation

import (
	"context"
	"log/slog"
	"time"
)

// Cron periodically runs OSS delete reconciliation against media-svc (stub).
type Cron struct {
	svc      *Service
	interval time.Duration
}

// NewCron creates a reconciliation cron placeholder.
func NewCron(svc *Service, interval time.Duration) *Cron {
	if interval <= 0 {
		interval = 15 * time.Minute
	}
	return &Cron{svc: svc, interval: interval}
}

// RunOnce executes reconciliation immediately.
func (c *Cron) RunOnce(ctx context.Context) (Result, error) {
	if c == nil || c.svc == nil {
		return Result{}, nil
	}
	return c.svc.RunOnce(ctx)
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
	result, err := c.svc.RunOnce(ctx)
	if err != nil {
		slog.Warn("oss delete reconciliation cron failed", "error", err)
		return
	}
	if result.HasIssues() {
		slog.Warn("oss delete reconciliation cron completed with discrepancies",
			"stale", result.Stale,
			"orphan_count", len(result.Orphans),
		)
		return
	}
	slog.Info("oss delete reconciliation cron ok",
		"pending", result.Pending,
		"dispatched", result.Dispatched,
		"confirmed", result.Confirmed,
	)
}
