package reconciliation

import (
	"context"
	"log/slog"
	"strings"
	"time"

	"github.com/baobao/feed-svc/internal/mediaclient"
)

const reconcileLogPrefix = "RECONCILE"

// Discrepancy describes one OSS delete reconciliation mismatch.
type Discrepancy struct {
	JobID     string
	PostID    string
	ObjectKey string
	Status    string
	Note      string
}

// Result is the outcome of one reconciliation run.
type Result struct {
	Pending    int
	Dispatched int
	Confirmed  int
	Stale      int
	Orphans    []Discrepancy
}

// HasIssues reports whether manual follow-up may be required.
func (r Result) HasIssues() bool {
	return r.Stale > 0 || len(r.Orphans) > 0
}

// JobSource exposes OSS cleanup job snapshots for reconciliation.
type JobSource interface {
	ListJobs() []mediaclient.DeleteJob
}

// Service reconciles feed-svc OSS delete jobs with media-svc / object storage events (stub).
type Service struct {
	jobs       JobSource
	staleAfter time.Duration
	now        func() time.Time
}

// NewService creates an OSS delete reconciliation service.
func NewService(jobs JobSource, staleAfter time.Duration) *Service {
	if staleAfter <= 0 {
		staleAfter = 24 * time.Hour
	}
	return &Service{
		jobs:       jobs,
		staleAfter: staleAfter,
		now:        time.Now,
	}
}

// RunOnce scans OSS cleanup jobs and logs reconciliation outcomes.
func (s *Service) RunOnce(ctx context.Context) (Result, error) {
	if s == nil || s.jobs == nil {
		return Result{}, nil
	}
	_ = ctx

	now := s.now().UTC()
	result := Result{}
	for _, job := range s.jobs.ListJobs() {
		switch job.Status {
		case mediaclient.JobStatusPending:
			result.Pending++
			if now.Sub(job.CreatedAt) > s.staleAfter {
				result.Stale++
				result.Orphans = append(result.Orphans, Discrepancy{
					JobID:     job.JobID,
					PostID:    job.PostID,
					ObjectKey: job.ObjectKey,
					Status:    job.Status,
					Note:      "pending_beyond_24h",
				})
			}
		case mediaclient.JobStatusDispatched:
			result.Dispatched++
			if now.Sub(job.UpdatedAt) > s.staleAfter {
				result.Stale++
				result.Orphans = append(result.Orphans, Discrepancy{
					JobID:     job.JobID,
					PostID:    job.PostID,
					ObjectKey: job.ObjectKey,
					Status:    job.Status,
					Note:      "await_media_svc_confirm",
				})
			}
		case mediaclient.JobStatusConfirmed:
			result.Confirmed++
		default:
			if strings.TrimSpace(job.ObjectKey) == "" {
				continue
			}
			result.Orphans = append(result.Orphans, Discrepancy{
				JobID:     job.JobID,
				PostID:    job.PostID,
				ObjectKey: job.ObjectKey,
				Status:    job.Status,
				Note:      "unknown_status",
			})
		}
	}

	slog.Info(reconcileLogPrefix+": oss_delete_reconcile",
		"pending", result.Pending,
		"dispatched", result.Dispatched,
		"confirmed", result.Confirmed,
		"stale", result.Stale,
		"orphan_count", len(result.Orphans),
	)
	for _, d := range result.Orphans {
		slog.Warn(reconcileLogPrefix+": discrepancy",
			"job_id", d.JobID,
			"post_id", d.PostID,
			"object_key", d.ObjectKey,
			"status", d.Status,
			"note", d.Note,
		)
	}
	return result, nil
}
