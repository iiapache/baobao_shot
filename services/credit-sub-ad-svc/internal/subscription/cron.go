package subscription

import (
	"context"
	"log/slog"
	"time"
)

// Cron periodically scans subscriptions and applies expiry fallback transitions.
type Cron struct {
	svc      *Service
	interval time.Duration
}

// NewCron creates a subscription expiry cron.
func NewCron(svc *Service, interval time.Duration) *Cron {
	if interval <= 0 {
		interval = 24 * time.Hour
	}
	return &Cron{svc: svc, interval: interval}
}

// RunOnce executes a single expiry scan immediately.
func (c *Cron) RunOnce(ctx context.Context) (int, error) {
	if c == nil || c.svc == nil {
		return 0, nil
	}
	return c.svc.RunExpiryScan(ctx)
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
	n, err := c.svc.RunExpiryScan(ctx)
	if err != nil {
		slog.Warn("subscription expiry cron failed", "error", err)
		return
	}
	if n > 0 {
		slog.Info("subscription expiry cron updated", "count", n)
	}
}
