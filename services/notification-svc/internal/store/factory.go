package store

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/baobao/notification-svc/internal/config"
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
		if err := applyEmbeddedMigrations(ctx, db, migrationDirectionUp); err != nil {
			_ = db.Close()
			return nil, nil, err
		}
		return NewPostgresStore(db), db, nil
	default:
		return nil, nil, fmt.Errorf("unsupported storage backend %q", cfg.StorageBackend)
	}
}

type migrationDirection string

const (
	migrationDirectionUp   migrationDirection = "up"
	migrationDirectionDown migrationDirection = "down"
)

func applyEmbeddedMigrations(ctx context.Context, db *sql.DB, dir migrationDirection) error {
	suffix := ".up.sql"
	if dir == migrationDirectionDown {
		suffix = ".down.sql"
	}

	entries, err := migrationFS.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("read migrations dir: %w", err)
	}

	var files []string
	for _, entry := range entries {
		name := entry.Name()
		if strings.HasSuffix(name, suffix) {
			files = append(files, name)
		}
	}
	if dir == migrationDirectionDown {
		sort.Sort(sort.Reverse(sort.StringSlice(files)))
	} else {
		sort.Strings(files)
	}

	for _, name := range files {
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

// ApplyMigrations executes raw SQL (supports multiple statements).
func ApplyMigrations(ctx context.Context, db *sql.DB, sqlText string) error {
	_, err := db.ExecContext(ctx, sqlText)
	return err
}

// RollbackMigrations applies all embedded down migrations (newest first).
func RollbackMigrations(ctx context.Context, db *sql.DB) error {
	return applyEmbeddedMigrations(ctx, db, migrationDirectionDown)
}

// ListMigrationTables returns table names created by migrations.
func ListMigrationTables() []string {
	return []string{"device_tokens", "notifications", "notification_subscriptions"}
}

// WaitForPostgres retries Ping until the database is reachable.
func WaitForPostgres(ctx context.Context, db *sql.DB) error {
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		if err := db.PingContext(ctx); err == nil {
			return nil
		}
		time.Sleep(200 * time.Millisecond)
	}
	return db.PingContext(ctx)
}
