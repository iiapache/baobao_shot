package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"
)

// PostgresStore implements Store backed by PostgreSQL.
type PostgresStore struct {
	db *sql.DB
}

// NewPostgresStore wraps an existing *sql.DB connection pool.
func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{db: db}
}

func (s *PostgresStore) Ping(ctx context.Context) error {
	return s.db.PingContext(ctx)
}

// ApplyMigrations runs embedded SQL migrations.
func ApplyMigrations(ctx context.Context, db *sql.DB, sql string) error {
	if _, err := db.ExecContext(ctx, sql); err != nil {
		return fmt.Errorf("apply migration: %w", err)
	}
	return nil
}

// WaitForPostgres pings until the database is reachable or timeout elapses.
func WaitForPostgres(ctx context.Context, db *sql.DB) error {
	deadline, ok := ctx.Deadline()
	if !ok {
		deadline = time.Now().Add(10 * time.Second)
	}
	for time.Now().Before(deadline) {
		if err := db.PingContext(ctx); err == nil {
			return nil
		}
		time.Sleep(200 * time.Millisecond)
	}
	return db.PingContext(ctx)
}
