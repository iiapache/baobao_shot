package costmetering

import (
	"context"
	"log/slog"
	"time"
)

// Cron periodically emits weekly reconciliation logs (internal stub for T7.10 dashboards).
type Cron struct {
	svc      *Service
	interval time.Duration
}

// NewCron creates a weekly report cron stub.
func NewCron(svc *Service, interval time.Duration) *Cron {
	if interval <= 0 {
		interval = 7 * 24 * time.Hour
	}
	return &Cron{svc: svc, interval: interval}
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
	report, err := c.svc.WeeklyReport(ctx, WeekStart(time.Now().UTC()))
	if err != nil {
		slog.Warn("weekly cost reconciliation failed", "error", err)
		return
	}
	slog.Info("weekly cost reconciliation",
		"weekStart", report.WeekStart.Format(time.RFC3339),
		"weekEnd", report.WeekEnd.Format(time.RFC3339),
		"records", report.TotalRecords,
		"totalCredits", report.TotalCredits,
		"totalVendorCostCNY", report.TotalVendorCostCNY,
		"byCapability", report.ByCapability,
	)
}
