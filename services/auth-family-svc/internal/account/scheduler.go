package account

import (
	"context"
	"log/slog"
	"time"
)

// Scheduler runs periodic account hard-deletion jobs.
// Wire to cron (e.g. hourly) in production; this stub is invoked manually or from main when enabled.
type Scheduler struct {
	svc      *Service
	interval time.Duration
	now      func() time.Time
}

// NewScheduler creates a deletion job scheduler.
func NewScheduler(svc *Service, interval time.Duration) *Scheduler {
	if interval <= 0 {
		interval = time.Hour
	}
	return &Scheduler{svc: svc, interval: interval, now: time.Now}
}

// RunOnce processes all due hard deletions immediately.
func (s *Scheduler) RunOnce(ctx context.Context) (int, error) {
	return s.svc.ProcessDueHardDeletions(ctx)
}

// Run starts the periodic deletion loop until ctx is cancelled.
func (s *Scheduler) Run(ctx context.Context) {
	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()

	slog.Info("account deletion scheduler started", "interval", s.interval.String())

	for {
		select {
		case <-ctx.Done():
			slog.Info("account deletion scheduler stopped")
			return
		case <-ticker.C:
			n, err := s.svc.ProcessDueHardDeletions(ctx)
			if err != nil {
				slog.Error("account deletion scheduler tick failed", "error", err)
				continue
			}
			if n > 0 {
				slog.Info("account deletion scheduler processed", "count", n)
			}
		}
	}
}
