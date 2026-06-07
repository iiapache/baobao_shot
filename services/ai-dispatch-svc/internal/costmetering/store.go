package costmetering

import (
	"context"
	"fmt"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/config"
)

// Store persists cost metering records.
type Store interface {
	Insert(ctx context.Context, record *Record) error
	ListByTaskID(ctx context.Context, taskID string) ([]Record, error)
	ListByTimeRange(ctx context.Context, start, end time.Time) ([]Record, error)
	Close(ctx context.Context) error
}

// NewStore returns a cost metering store for the configured backend.
func NewStore(cfg *config.Config) (Store, error) {
	if cfg == nil {
		return NewMemoryStore(), nil
	}
	switch cfg.StoreBackend {
	case "memory":
		return NewMemoryStore(), nil
	case "mongo":
		return NewMongoStore(cfg)
	default:
		return nil, fmt.Errorf("unsupported store backend %q", cfg.StoreBackend)
	}
}
