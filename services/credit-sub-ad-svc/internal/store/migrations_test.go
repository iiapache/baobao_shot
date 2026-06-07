package store

import (
	"context"
	"database/sql"
	"os"
	"strings"
	"testing"

	_ "github.com/lib/pq"
)

func TestMemoryStorePing(t *testing.T) {
	st := NewMemoryStore()
	if err := st.Ping(context.Background()); err != nil {
		t.Fatalf("Ping() error = %v", err)
	}
}

func TestMigrationSchemaDefinesAllTables(t *testing.T) {
	files := []string{
		"migrations/001_initial_schema.up.sql",
		"migrations/002_credit_reconciliation.up.sql",
	}
	for _, table := range ListMigrationTables() {
		found := false
		for _, file := range files {
			up, err := migrationFS.ReadFile(file)
			if err != nil {
				t.Fatalf("read up migration %s: %v", file, err)
			}
			if strings.Contains(string(up), "CREATE TABLE IF NOT EXISTS "+table) {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("no up migration defines table %q", table)
		}
	}
}

func TestMigrationDownDropsAllTables(t *testing.T) {
	files := []string{
		"migrations/001_initial_schema.down.sql",
		"migrations/002_credit_reconciliation.down.sql",
	}
	for _, table := range ListMigrationTables() {
		found := false
		for _, file := range files {
			down, err := migrationFS.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			if strings.Contains(string(down), "DROP TABLE IF EXISTS "+table) {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("no down migration drops table %q", table)
		}
	}
}

func TestMigrationUpDownRoundTrip(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping postgres migration round-trip")
	}

	ctx := context.Background()
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("open postgres: %v", err)
	}
	defer db.Close()

	if err := WaitForPostgres(ctx, db); err != nil {
		t.Fatalf("postgres not ready: %v", err)
	}
	if err := RollbackMigrations(ctx, db); err != nil {
		t.Fatalf("rollback before test: %v", err)
	}

	if err := ApplyMigrationFiles(ctx, db, "migrations/001_initial_schema.up.sql", "migrations/002_credit_reconciliation.up.sql"); err != nil {
		t.Fatalf("apply up: %v", err)
	}
	for _, table := range ListMigrationTables() {
		if !tableExists(ctx, t, db, table) {
			t.Fatalf("table %q not found after up migration", table)
		}
	}

	if err := ApplyMigrationFiles(ctx, db, "migrations/002_credit_reconciliation.down.sql", "migrations/001_initial_schema.down.sql"); err != nil {
		t.Fatalf("apply down: %v", err)
	}
	for _, table := range ListMigrationTables() {
		if tableExists(ctx, t, db, table) {
			t.Fatalf("table %q still exists after down migration", table)
		}
	}
}

func tableExists(ctx context.Context, t *testing.T, db *sql.DB, name string) bool {
	t.Helper()
	const q = `SELECT EXISTS (
		SELECT 1 FROM information_schema.tables
		WHERE table_schema = 'public' AND table_name = $1
	)`
	var exists bool
	if err := db.QueryRowContext(ctx, q, name).Scan(&exists); err != nil {
		t.Fatalf("check table %q: %v", name, err)
	}
	return exists
}
