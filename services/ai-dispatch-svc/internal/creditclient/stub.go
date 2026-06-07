package creditclient

import (
	"context"
	"fmt"
	"sync"

	"github.com/google/uuid"
)

type holdState string

const (
	holdStateHeld      holdState = "held"
	holdStateCommitted holdState = "committed"
	holdStateReleased  holdState = "released"
)

type holdRecord struct {
	holdID string
	userID string
	taskID string
	amount int32
	state  holdState
}

// Stub is an in-memory credit-sub-ad-svc client for tests and local dev.
type Stub struct {
	mu sync.Mutex
	// idempotency key -> hold id (hold saga)
	holdKeys map[string]string
	// hold id -> record
	holds map[string]*holdRecord
	// idempotency key -> settled (commit/release)
	settledKeys map[string]bool
	// audit trail for tests
	held      []HoldRequest
	committed []SettleRequest
	released  []SettleRequest
}

// NewStub returns an empty credit client stub.
func NewStub() *Stub {
	return &Stub{
		holdKeys:    make(map[string]string),
		holds:       make(map[string]*holdRecord),
		settledKeys: make(map[string]bool),
	}
}

// Hold reserves credits; duplicate ref_kind+ref_id returns the original hold id.
func (s *Stub) Hold(_ context.Context, req HoldRequest) (*HoldResponse, error) {
	req = NormalizeHold(req)
	if req.UserID == "" || req.TaskID == "" || req.Amount <= 0 {
		return nil, fmt.Errorf("%w: userId, taskId and positive amount required", ErrInvalidRequest)
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	key := IdempotencyKey(req.RefKind, req.RefID)
	if holdID, ok := s.holdKeys[key]; ok {
		return &HoldResponse{HoldID: holdID, Duplicate: true}, nil
	}

	holdID := "hld_" + uuid.NewString()
	s.holdKeys[key] = holdID
	s.holds[holdID] = &holdRecord{
		holdID: holdID,
		userID: req.UserID,
		taskID: req.TaskID,
		amount: req.Amount,
		state:  holdStateHeld,
	}
	s.held = append(s.held, req)
	return &HoldResponse{HoldID: holdID}, nil
}

// Commit finalizes a hold; duplicate ref_kind+ref_id is a no-op.
func (s *Stub) Commit(_ context.Context, req SettleRequest) error {
	req = NormalizeCommit(req)
	if req.HoldID == "" {
		return fmt.Errorf("%w: holdId required", ErrInvalidRequest)
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	key := IdempotencyKey(req.RefKind, req.RefID)
	if s.settledKeys[key] {
		return nil
	}

	rec, ok := s.holds[req.HoldID]
	if !ok {
		// Holds may be created by REST orchestration before worker settlement (T3.14).
		rec = &holdRecord{
			holdID: req.HoldID,
			taskID: req.TaskID,
			state:  holdStateHeld,
		}
		s.holds[req.HoldID] = rec
	}
	if rec.state != holdStateHeld {
		return ErrHoldSettled
	}

	rec.state = holdStateCommitted
	s.settledKeys[key] = true
	s.committed = append(s.committed, req)
	return nil
}

// Release refunds a hold; duplicate ref_kind+ref_id is a no-op.
func (s *Stub) Release(_ context.Context, req SettleRequest) error {
	req = NormalizeRelease(req)
	if req.HoldID == "" {
		return fmt.Errorf("%w: holdId required", ErrInvalidRequest)
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	key := IdempotencyKey(req.RefKind, req.RefID)
	if s.settledKeys[key] {
		return nil
	}

	rec, ok := s.holds[req.HoldID]
	if !ok {
		rec = &holdRecord{
			holdID: req.HoldID,
			taskID: req.TaskID,
			state:  holdStateHeld,
		}
		s.holds[req.HoldID] = rec
	}
	if rec.state != holdStateHeld {
		return ErrHoldSettled
	}

	rec.state = holdStateReleased
	s.settledKeys[key] = true
	s.released = append(s.released, req)
	return nil
}

// Held returns recorded hold requests.
func (s *Stub) Held() []HoldRequest {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]HoldRequest, len(s.held))
	copy(out, s.held)
	return out
}

// Committed returns recorded commit requests.
func (s *Stub) Committed() []SettleRequest {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]SettleRequest, len(s.committed))
	copy(out, s.committed)
	return out
}

// Released returns recorded release requests.
func (s *Stub) Released() []SettleRequest {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]SettleRequest, len(s.released))
	copy(out, s.released)
	return out
}
