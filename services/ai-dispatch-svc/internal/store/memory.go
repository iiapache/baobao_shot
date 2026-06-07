package store

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// MemoryTaskStore is an in-memory ai_tasks store for tests and local dev.
type MemoryTaskStore struct {
	mu    sync.RWMutex
	tasks map[string]*model.Task
}

// NewMemoryTaskStore creates an empty in-memory store.
func NewMemoryTaskStore() *MemoryTaskStore {
	return &MemoryTaskStore{tasks: make(map[string]*model.Task)}
}

// Create inserts a new task document.
func (s *MemoryTaskStore) Create(_ context.Context, task *model.Task) error {
	if task == nil || task.ID == "" {
		return fmt.Errorf("task id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.tasks[task.ID]; exists {
		return fmt.Errorf("task %s already exists", task.ID)
	}
	copyTask := *task
	s.tasks[task.ID] = &copyTask
	return nil
}

// GetByID returns a task by id.
func (s *MemoryTaskStore) GetByID(_ context.Context, id string) (*model.Task, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	task, ok := s.tasks[id]
	if !ok {
		return nil, ErrNotFound
	}
	copyTask := *task
	return &copyTask, nil
}

// UpdateState updates task state and appends state history.
func (s *MemoryTaskStore) UpdateState(ctx context.Context, id string, state string, at time.Time) error {
	return s.UpdateTask(ctx, id, TaskPatch{State: state, UpdatedAt: at})
}

// UpdateTask applies partial updates to a task document.
func (s *MemoryTaskStore) UpdateTask(_ context.Context, id string, patch TaskPatch) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	task, ok := s.tasks[id]
	if !ok {
		return ErrNotFound
	}
	if patch.State != "" {
		task.State = patch.State
		at := patch.UpdatedAt
		if at.IsZero() {
			at = time.Now().UTC()
		}
		task.StateHistory = append(task.StateHistory, model.StateHistoryEntry{State: patch.State, At: at})
	}
	if patch.Model != nil {
		task.Model = *patch.Model
	}
	if patch.ModelRetryCount != nil {
		task.ModelRetryCount = *patch.ModelRetryCount
	}
	if patch.Output != nil {
		task.Output = *patch.Output
	}
	if patch.DeepSynth != nil {
		task.DeepSynth = *patch.DeepSynth
	}
	if patch.AppendInvocation != nil {
		task.ModelInvocations = append(task.ModelInvocations, *patch.AppendInvocation)
	}
	if !patch.UpdatedAt.IsZero() {
		task.UpdatedAt = patch.UpdatedAt
	}
	return nil
}

// Close is a no-op for memory store.
func (s *MemoryTaskStore) Close(_ context.Context) error {
	return nil
}
