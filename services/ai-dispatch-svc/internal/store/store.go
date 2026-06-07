package store

import (
	"context"
	"fmt"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/config"
	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// TaskPatch carries optional field updates applied atomically by the worker layer.
type TaskPatch struct {
	State              string
	Model              *string
	ModelRetryCount    *int
	Output             *model.TaskOutput
	DeepSynth          *model.DeepSynthMetadata
	AppendInvocation   *model.ModelInvocation
	UpdatedAt          time.Time
}

// TaskStore persists ai_tasks documents.
type TaskStore interface {
	Create(ctx context.Context, task *model.Task) error
	GetByID(ctx context.Context, id string) (*model.Task, error)
	UpdateState(ctx context.Context, id string, state string, at time.Time) error
	UpdateTask(ctx context.Context, id string, patch TaskPatch) error
	Close(ctx context.Context) error
}

// NewTaskStore returns a store for the configured backend.
func NewTaskStore(cfg *config.Config) (TaskStore, error) {
	if cfg == nil {
		return NewMemoryTaskStore(), nil
	}
	switch cfg.StoreBackend {
	case "memory":
		return NewMemoryTaskStore(), nil
	case "mongo":
		return NewMongoTaskStore(cfg)
	default:
		return nil, fmt.Errorf("unsupported store backend %q", cfg.StoreBackend)
	}
}
