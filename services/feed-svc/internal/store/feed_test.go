package store

import (
	"context"
	"database/sql"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/baobao/feed-svc/internal/model"
	_ "github.com/lib/pq"
)

func TestMemoryStorePing(t *testing.T) {
	st := NewMemoryStore()
	if err := st.Ping(context.Background()); err != nil {
		t.Fatalf("Ping() error = %v", err)
	}
}

func TestMemoryPostLifecycle(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)

	post, err := st.CreatePost(ctx, CreatePostInput{
		ID: "post_1", FamilyID: "fam_1", OwnerUserID: "usr_1",
		BabyIDs: []string{"baby_1"}, Caption: "hello", Visibility: model.VisibilityFamily,
		Status: model.PostStatusAudit, CreatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}
	if post.ID != "post_1" {
		t.Fatalf("post id = %s", post.ID)
	}

	item, err := st.CreatePostItem(ctx, CreatePostItemInput{
		ID: "item_1", PostID: "post_1", Kind: model.ItemKindImage,
		ObjectKey: "media/a.jpg", Mime: "image/jpeg", Width: 100, Height: 100,
	})
	if err != nil {
		t.Fatal(err)
	}
	if item.PostID != "post_1" {
		t.Fatalf("item post_id = %s", item.PostID)
	}

	items, err := st.ListPostItems(ctx, "post_1")
	if err != nil || len(items) != 1 {
		t.Fatalf("items = %+v, err = %v", items, err)
	}

	if err := st.AddLike(ctx, "post_1", "usr_2", now); err != nil {
		t.Fatal(err)
	}
	if err := st.AddLike(ctx, "post_1", "usr_2", now); err != ErrDuplicateLike {
		t.Fatalf("duplicate like err = %v", err)
	}

	comment, err := st.CreateComment(ctx, CreateCommentInput{
		ID: "cmt_1", PostID: "post_1", UserID: "usr_2", Text: "nice", Status: model.CommentStatusPublished, CreatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}
	if comment.ID != "cmt_1" {
		t.Fatalf("comment id = %s", comment.ID)
	}

	log, err := st.CreateAuditLog(ctx, CreateAuditLogInput{
		ID: "aud_1", TargetKind: "post", TargetID: "post_1", Result: "pass",
		Reasons: []string{"ok"}, Reviewer: "system", CreatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}
	if log.TargetID != "post_1" {
		t.Fatalf("audit target = %s", log.TargetID)
	}

	if err := st.SoftDeleteComment(ctx, "cmt_1", now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if err := st.SoftDeletePost(ctx, "post_1", now.Add(2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if _, err := st.GetPost(ctx, "post_1"); err != ErrNotFound {
		t.Fatalf("GetPost after delete err = %v", err)
	}
}

func TestMemorySoftDeletePostItemsByPostID(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)

	_, err := st.CreatePost(ctx, CreatePostInput{
		ID: "post_items", FamilyID: "fam_1", OwnerUserID: "usr_1",
		Status: model.PostStatusPublished, Visibility: model.VisibilityFamily, CreatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}
	_, err = st.CreatePostItem(ctx, CreatePostItemInput{
		ID: "item_a", PostID: "post_items", Kind: model.ItemKindImage,
		ObjectKey: "media/a.jpg", Mime: "image/jpeg", Width: 1, Height: 1,
	})
	if err != nil {
		t.Fatal(err)
	}

	if err := st.SoftDeletePostItemsByPostID(ctx, "post_items", now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	items, err := st.ListPostItems(ctx, "post_items")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 0 {
		t.Fatalf("items = %+v, want hidden", items)
	}
}

func TestMemoryUpdatePostStatus(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)

	_, err := st.CreatePost(ctx, CreatePostInput{
		ID: "post_status", FamilyID: "fam_1", OwnerUserID: "usr_1",
		Status: model.PostStatusAudit, Visibility: model.VisibilityFamily, CreatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}
	audited := now.Add(time.Minute)
	if err := st.UpdatePostStatus(ctx, "post_status", model.PostStatusPublished, &audited); err != nil {
		t.Fatal(err)
	}
	post, err := st.GetPost(ctx, "post_status")
	if err != nil {
		t.Fatal(err)
	}
	if post.Status != model.PostStatusPublished || post.AuditedAt == nil {
		t.Fatalf("post = %+v", post)
	}
}

func TestMigrationSchemaDefinesAllTables(t *testing.T) {
	up, err := migrationFS.ReadFile("migrations/001_initial_schema.up.sql")
	if err != nil {
		t.Fatalf("read up migration: %v", err)
	}
	content := string(up)
	for _, table := range ListMigrationTables() {
		if !strings.Contains(content, "CREATE TABLE IF NOT EXISTS "+table) {
			t.Fatalf("up migration missing table %q", table)
		}
	}
}

func TestMigrationDownDropsAllTables(t *testing.T) {
	down, err := migrationFS.ReadFile("migrations/001_initial_schema.down.sql")
	if err != nil {
		t.Fatal(err)
	}
	content := string(down)
	for _, table := range ListMigrationTables() {
		if !strings.Contains(content, "DROP TABLE IF EXISTS "+table) {
			t.Fatalf("down migration missing drop for table %q", table)
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

	if err := ApplyMigrationFiles(ctx, db, "migrations/001_initial_schema.up.sql"); err != nil {
		t.Fatalf("apply up: %v", err)
	}
	for _, table := range ListMigrationTables() {
		if !tableExists(ctx, t, db, table) {
			t.Fatalf("table %q not found after up migration", table)
		}
	}

	if err := ApplyMigrationFiles(ctx, db, "migrations/001_initial_schema.down.sql"); err != nil {
		t.Fatalf("apply down: %v", err)
	}
	for _, table := range ListMigrationTables() {
		if tableExists(ctx, t, db, table) {
			t.Fatalf("table %q still exists after down migration", table)
		}
	}
}

func TestPostgresPostLifecycle(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping postgres store test")
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
		t.Fatalf("rollback: %v", err)
	}
	if err := ApplyMigrationFiles(ctx, db, "migrations/001_initial_schema.up.sql"); err != nil {
		t.Fatalf("migrate up: %v", err)
	}
	defer func() { _ = RollbackMigrations(ctx, db) }()

	st := NewPostgresStore(db)
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)

	if _, err := st.CreatePost(ctx, CreatePostInput{
		ID: "post_pg", FamilyID: "fam_pg", OwnerUserID: "usr_pg",
		BabyIDs: []string{"baby_pg"}, Caption: "pg", Visibility: model.VisibilityFamily,
		Status: model.PostStatusPublished, CreatedAt: now,
	}); err != nil {
		t.Fatal(err)
	}
	got, err := st.GetPost(ctx, "post_pg")
	if err != nil || got.Caption != "pg" {
		t.Fatalf("GetPost = %+v, err = %v", got, err)
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
