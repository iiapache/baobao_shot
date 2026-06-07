package store

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"strings"

	"github.com/baobao/audit-svc/internal/config"
	_ "github.com/lib/pq"
)

// New opens the configured storage backend.
func New(ctx context.Context, cfg *config.Config) (Store, *sql.DB, error) {
	switch cfg.StorageBackend {
	case "memory":
		return NewMemoryStore(), nil, nil
	case "postgres":
		if cfg.DatabaseURL == "" {
			return nil, nil, fmt.Errorf("DATABASE_URL required when STORAGE_BACKEND=postgres")
		}
		db, err := sql.Open("postgres", cfg.DatabaseURL)
		if err != nil {
			return nil, nil, fmt.Errorf("open postgres: %w", err)
		}
		if err := WaitForPostgres(ctx, db); err != nil {
			_ = db.Close()
			return nil, nil, fmt.Errorf("postgres not ready: %w", err)
		}
		if err := applyEmbeddedMigrations(ctx, db); err != nil {
			_ = db.Close()
			return nil, nil, err
		}
		return NewPostgresStore(db), db, nil
	default:
		return nil, nil, fmt.Errorf("unsupported storage backend %q", cfg.StorageBackend)
	}
}

func applyEmbeddedMigrations(ctx context.Context, db *sql.DB) error {
	entries, err := migrationFS.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("read migrations dir: %w", err)
	}

	var upFiles []string
	for _, entry := range entries {
		name := entry.Name()
		if strings.HasSuffix(name, ".up.sql") {
			upFiles = append(upFiles, name)
		}
	}
	sort.Strings(upFiles)

	for _, name := range upFiles {
		sqlBytes, err := migrationFS.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", name, err)
		}
		if err := ApplyMigrations(ctx, db, string(sqlBytes)); err != nil {
			return fmt.Errorf("apply migration %s: %w", name, err)
		}
	}
	return nil
}
