package store

import (
	"fmt"

	"github.com/baobao/config-svc/internal/config"
	"github.com/baobao/config-svc/internal/feature"
)

// PlayDefinition is a placeholder play catalog entry.
type PlayDefinition struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description,omitempty"`
	Regions     []string `json:"regions,omitempty"`
	Enabled     bool     `json:"enabled"`
}

// Snapshot is the full config payload served to clients.
type Snapshot struct {
	Version  string              `json:"version"`
	Features []feature.Definition `json:"features"`
	Plays    []PlayDefinition    `json:"plays"`
}

// Store reads feature and play definitions.
type Store interface {
	GetSnapshot() Snapshot
}

// New creates a Store from runtime configuration.
func New(cfg *config.Config) (Store, error) {
	switch cfg.Storage.Backend {
	case "memory":
		return NewMemoryStore(), nil
	case "redis":
		return NewRedisStore(cfg.Storage.RedisURL)
	default:
		return nil, fmt.Errorf("unsupported storage backend: %s", cfg.Storage.Backend)
	}
}
