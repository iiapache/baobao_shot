package family

import (
	"context"
	"log/slog"
	"time"
)

// Scheduler runs periodic takeover completion jobs.
type Scheduler struct {
	svc      *Service
	interval time.Duration
}

// NewScheduler creates a takeover completion scheduler.
func NewScheduler(svc *Service, interval time.Duration) *Scheduler {
	if interval <= 0 {
		interval = time.Hour
	}
	return &Scheduler{svc: svc, interval: interval}
}

// RunOnce completes all takeover votes whose objection period has elapsed.
func (s *Scheduler) RunOnce(ctx context.Context) (int, error) {
	return s.svc.ProcessDueTakeovers(ctx)
}

// Run starts the periodic takeover completion loop until ctx is cancelled.
func (s *Scheduler) Run(ctx context.Context) {
	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()

	slog.Info("family takeover scheduler started", "interval", s.interval.String())

	for {
		select {
		case <-ctx.Done():
			slog.Info("family takeover scheduler stopped")
			return
		case <-ticker.C:
			n, err := s.svc.ProcessDueTakeovers(ctx)
			if err != nil {
				slog.Error("family takeover scheduler tick failed", "error", err)
				continue
			}
			if n > 0 {
				slog.Info("family takeover scheduler processed", "count", n)
			}
		}
	}
}
