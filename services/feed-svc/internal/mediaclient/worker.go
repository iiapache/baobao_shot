package mediaclient

import (
	"context"
	"log/slog"
	"time"
)

// WorkerStub periodically dispatches pending OSS delete jobs (T5.5 async cleanup stub).
type WorkerStub struct {
	stub     *Stub
	interval time.Duration
}

// NewWorkerStub creates an async OSS cleanup worker over the in-memory stub.
func NewWorkerStub(stub *Stub, interval time.Duration) *WorkerStub {
	if stub == nil {
		stub = NewStub()
	}
	if interval <= 0 {
		interval = time.Minute
	}
	return &WorkerStub{stub: stub, interval: interval}
}

// RunOnce dispatches all pending delete jobs immediately.
func (w *WorkerStub) RunOnce() int {
	if w == nil || w.stub == nil {
		return 0
	}
	n := w.stub.DispatchPending(0)
	if n > 0 {
		slog.Info("oss cleanup worker stub dispatched deletes", "count", n)
	}
	return n
}

// Start runs the worker loop until ctx is cancelled.
func (w *WorkerStub) Start(ctx context.Context) {
	if w == nil || w.stub == nil {
		return
	}
	go func() {
		w.RunOnce()
		ticker := time.NewTicker(w.interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				w.RunOnce()
			}
		}
	}()
}
