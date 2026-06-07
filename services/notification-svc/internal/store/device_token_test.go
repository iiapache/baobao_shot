package store

import (
	"context"
	"database/sql"
	"os"
	"strings"
	"testing"
	"time"

	_ "github.com/lib/pq"
)

func TestMemoryStoreDeviceTokenLifecycle(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"

	dt, err := st.UpsertDeviceToken(ctx, UpsertDeviceTokenInput{
		UserID: "usr_1", DeviceID: "dev_1", APNSToken: token,
		Region: "cn", AppVersion: "1.0.0", UpdatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}
	if dt.Region != "cn" {
		t.Fatalf("region = %s", dt.Region)
	}

	got, err := st.GetDeviceToken(ctx, "usr_1", "dev_1")
	if err != nil {
		t.Fatal(err)
	}
	if got.APNSToken != token {
		t.Fatalf("token = %s", got.APNSToken)
	}

	list, err := st.ListDeviceTokensByUser(ctx, "usr_1")
	if err != nil || len(list) != 1 {
		t.Fatalf("list = %+v, err = %v", list, err)
	}

	n, err := st.DeleteByAPNSToken(ctx, token)
	if err != nil || n != 1 {
		t.Fatalf("removed = %d, err = %v", n, err)
	}
	if err := st.DeleteDeviceToken(ctx, "usr_1", "dev_1"); err != ErrNotFound {
		t.Fatalf("delete missing err = %v", err)
	}
}

func TestMigrationRoundTrip(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}

	ctx := context.Background()
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	if err := WaitForPostgres(ctx, db); err != nil {
		t.Fatal(err)
	}

	if err := applyEmbeddedMigrations(ctx, db, migrationDirectionUp); err != nil {
		t.Fatal(err)
	}

	for _, table := range ListMigrationTables() {
		var exists bool
		q := `SELECT EXISTS (
			SELECT 1 FROM information_schema.tables
			WHERE table_schema = 'public' AND table_name = $1
		)`
		if err := db.QueryRowContext(ctx, q, table).Scan(&exists); err != nil {
			t.Fatal(err)
		}
		if !exists {
			t.Fatalf("table %s missing", table)
		}
	}

	if err := RollbackMigrations(ctx, db); err != nil {
		t.Fatal(err)
	}

	var remaining int
	if err := db.QueryRowContext(ctx, `
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = ANY($1)`, pqStringArray(ListMigrationTables())).Scan(&remaining); err != nil {
		// fallback count
		for _, table := range ListMigrationTables() {
			var exists bool
			_ = db.QueryRowContext(ctx, `SELECT EXISTS (
				SELECT 1 FROM information_schema.tables
				WHERE table_schema = 'public' AND table_name = $1
			)`, table).Scan(&exists)
			if exists {
				remaining++
			}
		}
	}
	if remaining > 0 {
		t.Fatalf("tables still present after rollback: %d", remaining)
	}
}

func pqStringArray(items []string) string {
	return "{" + strings.Join(items, ",") + "}"
}

func TestPostgresStoreDeviceToken(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}

	ctx := context.Background()
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	if err := WaitForPostgres(ctx, db); err != nil {
		t.Fatal(err)
	}
	if err := applyEmbeddedMigrations(ctx, db, migrationDirectionUp); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = RollbackMigrations(context.Background(), db) })

	st := NewPostgresStore(db)
	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	now := time.Now().UTC()

	_, err = st.UpsertDeviceToken(ctx, UpsertDeviceTokenInput{
		UserID: "usr_pg", DeviceID: "dev_pg", APNSToken: token,
		Region: "os", AppVersion: "2.0.0", UpdatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}

	if err := st.DeleteDeviceToken(ctx, "usr_pg", "dev_pg"); err != nil {
		t.Fatal(err)
	}
}
