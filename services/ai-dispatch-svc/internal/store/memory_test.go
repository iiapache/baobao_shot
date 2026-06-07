package store

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/baobao/ai-dispatch-svc/internal/statemachine"
)

func TestMemoryTaskStoreLifecycle(t *testing.T) {
	s := NewMemoryTaskStore()
	now := time.Now().UTC()
	task := &model.Task{
		ID:           "tsk_mem_1",
		UserID:       "usr_1",
		Region:       model.RegionCN,
		Style:        "ghibli_kid",
		Capability:   model.CapabilityImageGen,
		Input:        model.TaskInput{ObjectKey: "ai-tmp/usr_1/a.heic", SHA256: "abc"},
		State:        string(statemachine.StateCreated),
		StateHistory: []model.StateHistoryEntry{{State: string(statemachine.StateCreated), At: now}},
		CostCredits:  8,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	ctx := context.Background()
	if err := s.Create(ctx, task); err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if err := s.UpdateState(ctx, task.ID, string(statemachine.StateCreditHeld), now.Add(time.Second)); err != nil {
		t.Fatalf("UpdateState() error = %v", err)
	}

	got, err := s.GetByID(ctx, task.ID)
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if got.State != string(statemachine.StateCreditHeld) {
		t.Fatalf("State = %s, want credit_held", got.State)
	}
	if len(got.StateHistory) != 2 {
		t.Fatalf("StateHistory len = %d, want 2", len(got.StateHistory))
	}
}
