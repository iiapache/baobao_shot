package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/baobao/ai-dispatch-svc/internal/statemachine"
	"github.com/baobao/ai-dispatch-svc/internal/store"
)

func TestGetTaskStub(t *testing.T) {
	mem := store.NewMemoryTaskStore()
	now := time.Now().UTC()
	task := &model.Task{
		ID:        "tsk_grpc_test",
		UserID:    "usr_1",
		Region:    model.RegionCN,
		Style:     "ghibli_kid",
		Capability: model.CapabilityImageGen,
		Input:     model.TaskInput{ObjectKey: "ai-tmp/usr_1/test.heic"},
		State:     string(statemachine.StateCreated),
		StateHistory: []model.StateHistoryEntry{
			{State: string(statemachine.StateCreated), At: now},
		},
		CostCredits: 8,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if err := mem.Create(context.Background(), task); err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	srv := &AiDispatchServer{taskStore: mem}
	resp, err := srv.GetTask(context.Background(), &GetTaskRequest{TaskID: "tsk_grpc_test"})
	if err != nil {
		t.Fatalf("GetTask() error = %v", err)
	}
	if resp.State != string(statemachine.StateCreated) {
		t.Fatalf("State = %s, want created", resp.State)
	}
}
