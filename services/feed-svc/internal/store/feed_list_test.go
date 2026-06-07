package store

import (
	"context"
	"database/sql"
	"os"
	"testing"
	"time"

	"github.com/baobao/feed-svc/internal/model"
	_ "github.com/lib/pq"
)

func seedFamilyFeedPosts(t *testing.T, st Store, familyID string) {
	t.Helper()
	ctx := context.Background()
	base := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	posts := []CreatePostInput{
		{ID: "post_a", FamilyID: familyID, OwnerUserID: "usr_1", Status: model.PostStatusPublished, Visibility: model.VisibilityFamily, Caption: "a", CreatedAt: base.Add(3 * time.Minute)},
		{ID: "post_b", FamilyID: familyID, OwnerUserID: "usr_1", Status: model.PostStatusPublished, Visibility: model.VisibilityFamily, Caption: "b", CreatedAt: base.Add(2 * time.Minute)},
		{ID: "post_c", FamilyID: familyID, OwnerUserID: "usr_1", Status: model.PostStatusPublished, Visibility: model.VisibilityFamily, Caption: "c", CreatedAt: base.Add(time.Minute)},
		{ID: "post_self", FamilyID: familyID, OwnerUserID: "usr_1", Status: model.PostStatusPublished, Visibility: model.VisibilitySelf, Caption: "self", CreatedAt: base.Add(4 * time.Minute)},
		{ID: "post_removed", FamilyID: familyID, OwnerUserID: "usr_1", Status: model.PostStatusRemoved, Visibility: model.VisibilityFamily, Caption: "removed", CreatedAt: base.Add(5 * time.Minute)},
		{ID: "post_other", FamilyID: "fam_other", OwnerUserID: "usr_2", Status: model.PostStatusPublished, Visibility: model.VisibilityFamily, Caption: "other", CreatedAt: base},
	}
	for _, in := range posts {
		if _, err := st.CreatePost(ctx, in); err != nil {
			t.Fatal(err)
		}
	}
	if err := st.SoftDeletePost(ctx, "post_removed", base.Add(10*time.Minute)); err != nil {
		t.Fatal(err)
	}
}

func TestMemoryListFamilyPostsPagination(t *testing.T) {
	st := NewMemoryStore()
	seedFamilyFeedPosts(t, st, "fam_feed")
	ctx := context.Background()

	page1, err := st.ListFamilyPosts(ctx, ListFamilyPostsInput{FamilyID: "fam_feed", Limit: 2})
	if err != nil {
		t.Fatal(err)
	}
	if len(page1.Posts) != 2 || page1.NextCursor == "" {
		t.Fatalf("page1 = %+v", page1)
	}
	if page1.Posts[0].ID != "post_a" || page1.Posts[1].ID != "post_b" {
		t.Fatalf("page1 order = [%s, %s]", page1.Posts[0].ID, page1.Posts[1].ID)
	}

	page2, err := st.ListFamilyPosts(ctx, ListFamilyPostsInput{FamilyID: "fam_feed", Limit: 2, Cursor: page1.NextCursor})
	if err != nil {
		t.Fatal(err)
	}
	if len(page2.Posts) != 1 || page2.NextCursor != "" || page2.Posts[0].ID != "post_c" {
		t.Fatalf("page2 = %+v", page2)
	}
}

func TestMemoryListFamilyPostsInvalidCursor(t *testing.T) {
	st := NewMemoryStore()
	_, err := st.ListFamilyPosts(context.Background(), ListFamilyPostsInput{FamilyID: "fam_feed", Cursor: "bad"})
	if err != ErrInvalidCursor {
		t.Fatalf("err = %v", err)
	}
}

func TestPostgresListFamilyPosts(t *testing.T) {
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
	if err := RollbackMigrations(ctx, db); err != nil {
		t.Fatal(err)
	}
	if err := ApplyMigrationFiles(ctx, db, "migrations/001_initial_schema.up.sql"); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = RollbackMigrations(ctx, db) }()

	st := NewPostgresStore(db)
	seedFamilyFeedPosts(t, st, "fam_pg_feed")

	page, err := st.ListFamilyPosts(ctx, ListFamilyPostsInput{FamilyID: "fam_pg_feed", Limit: 10})
	if err != nil {
		t.Fatal(err)
	}
	if len(page.Posts) != 3 {
		t.Fatalf("posts = %d, want 3 family-visible published posts", len(page.Posts))
	}
}
