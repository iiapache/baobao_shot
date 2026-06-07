package creditclient

import (
	"context"
	"errors"
)

var (
	ErrInvalidRequest = errors.New("credit request invalid")
	ErrHoldNotFound   = errors.New("credit hold not found")
	ErrHoldSettled    = errors.New("credit hold already settled")
)

// Ref kinds for saga idempotency (design-backend §6.1, ref_kind + ref_id unique).
const (
	RefKindAITaskHold    = "ai_task_hold"
	RefKindAITaskCommit  = "ai_task_commit"
	RefKindAITaskRelease = "ai_task_release"
)

// HoldRequest reserves credits for an AI task.
type HoldRequest struct {
	UserID    string
	TaskID    string
	Amount    int32
	RefKind   string
	RefID     string
}

// SettleRequest commits or releases a prior hold.
type SettleRequest struct {
	HoldID  string
	TaskID  string
	RefKind string
	RefID   string
}

// HoldResponse carries the hold identifier from credit-sub-ad-svc.
type HoldResponse struct {
	HoldID    string
	Duplicate bool
}

// Client talks to credit-sub-ad-svc saga RPC (T3.14 / T4.3).
type Client interface {
	Hold(ctx context.Context, req HoldRequest) (*HoldResponse, error)
	Commit(ctx context.Context, req SettleRequest) error
	Release(ctx context.Context, req SettleRequest) error
}

// NormalizeHold fills default idempotency keys (ref_kind + ref_id = taskId).
func NormalizeHold(req HoldRequest) HoldRequest {
	if req.RefKind == "" {
		req.RefKind = RefKindAITaskHold
	}
	if req.RefID == "" {
		req.RefID = req.TaskID
	}
	return req
}

// NormalizeCommit fills default idempotency keys for commit.
func NormalizeCommit(req SettleRequest) SettleRequest {
	if req.RefKind == "" {
		req.RefKind = RefKindAITaskCommit
	}
	if req.RefID == "" {
		req.RefID = req.TaskID
	}
	return req
}

// NormalizeRelease fills default idempotency keys for release.
func NormalizeRelease(req SettleRequest) SettleRequest {
	if req.RefKind == "" {
		req.RefKind = RefKindAITaskRelease
	}
	if req.RefID == "" {
		req.RefID = req.TaskID
	}
	return req
}

// IdempotencyKey returns the ledger idempotency tuple.
func IdempotencyKey(refKind, refID string) string {
	return refKind + ":" + refID
}
