package mediaclient

import (
	"context"
	"time"
)

const (
	JobStatusPending    = "pending"
	JobStatusDispatched = "dispatched"
	JobStatusConfirmed  = "confirmed"
)

// DeleteRequest enqueues one OSS object for async physical delete after post withdraw.
type DeleteRequest struct {
	PostID    string
	ObjectKey string
	Region    string
}

// DeleteJob tracks one async OSS cleanup task (persisted in production; stub in dev).
type DeleteJob struct {
	JobID      string
	PostID     string
	ObjectKey  string
	Region     string
	Status     string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

// Client schedules OSS object deletes (production calls media-svc gRPC).
type Client interface {
	EnqueueDeletes(ctx context.Context, reqs []DeleteRequest) ([]DeleteJob, error)
}
