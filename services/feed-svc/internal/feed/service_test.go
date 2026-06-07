package feed

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/baobao/feed-svc/internal/cache"
	"github.com/baobao/feed-svc/internal/familyauth"
	"github.com/baobao/feed-svc/internal/middleware"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/store"
)

func newTestFeedService(st store.Store) *Service {
	return NewService(st, cache.NewMemoryStore(), familyauth.NewStub())
}

func seedFeedServicePosts(t *testing.T, st store.Store) {
	t.Helper()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	for i, id := range []string{"post_3", "post_2", "post_1"} {
		if _, err := st.CreatePost(ctx, store.CreatePostInput{
			ID: id, FamilyID: "fam_svc", OwnerUserID: "usr_feed", Status: model.PostStatusPublished,
			Visibility: model.VisibilityFamily, Caption: id, CreatedAt: now.Add(time.Duration(i) * time.Minute),
		}); err != nil {
			t.Fatal(err)
		}
	}
}

func TestListFamilyFeedPagination(t *testing.T) {
	st := store.NewMemoryStore()
	seedFeedServicePosts(t, st)
	svc := newTestFeedService(st)
	ctx := middleware.WithFamilies(context.Background(), []middleware.FamilyClaim{{FamilyID: "fam_svc", Role: "family"}})

	page1, err := svc.List(ctx, ListInput{UserID: "usr_feed", FamilyID: "fam_svc", Limit: 2})
	if err != nil {
		t.Fatal(err)
	}
	if len(page1.Items) != 2 || page1.NextCursor == nil || page1.CacheTTLSeconds != 60 {
		t.Fatalf("page1 = %+v", page1)
	}

	page2, err := svc.List(ctx, ListInput{UserID: "usr_feed", FamilyID: "fam_svc", Limit: 2, Cursor: *page1.NextCursor})
	if err != nil {
		t.Fatal(err)
	}
	if len(page2.Items) != 1 || page2.NextCursor != nil {
		t.Fatalf("page2 = %+v", page2)
	}
}

func TestListFamilyFeedUsesCache(t *testing.T) {
	st := store.NewMemoryStore()
	seedFeedServicePosts(t, st)
	cacheStore := cache.NewMemoryStore()
	svc := NewService(st, cacheStore, familyauth.NewStub())
	ctx := middleware.WithFamilies(context.Background(), []middleware.FamilyClaim{{FamilyID: "fam_svc", Role: "family"}})

	first, err := svc.List(ctx, ListInput{UserID: "usr_feed", FamilyID: "fam_svc", Limit: 20})
	if err != nil {
		t.Fatal(err)
	}

	raw, ok, err := cacheStore.Get(ctx, feedCacheKey("fam_svc", "", 20))
	if err != nil || !ok {
		t.Fatalf("cache miss after list: ok=%v err=%v", ok, err)
	}
	var cached cachedPage
	if err := json.Unmarshal(raw, &cached); err != nil {
		t.Fatal(err)
	}
	if len(cached.Items) != len(first.Items) {
		t.Fatalf("cached items = %d, want %d", len(cached.Items), len(first.Items))
	}

	second, err := svc.List(ctx, ListInput{UserID: "usr_feed", FamilyID: "fam_svc", Limit: 20})
	if err != nil {
		t.Fatal(err)
	}
	if len(second.Items) != len(first.Items) {
		t.Fatalf("second = %+v", second)
	}
}

func TestListFamilyFeedForbidden(t *testing.T) {
	st := store.NewMemoryStore()
	svc := newTestFeedService(st)
	ctx := middleware.WithFamilies(context.Background(), []middleware.FamilyClaim{{FamilyID: "fam_other", Role: "family"}})
	_, err := svc.List(ctx, ListInput{UserID: "usr_feed", FamilyID: "fam_svc"})
	if err != ErrFamilyForbidden {
		t.Fatalf("err = %v", err)
	}
}

func TestListFamilyFeedRequiresAuth(t *testing.T) {
	svc := newTestFeedService(store.NewMemoryStore())
	_, err := svc.List(context.Background(), ListInput{FamilyID: "fam_svc"})
	if err != ErrUnauthorized {
		t.Fatalf("err = %v", err)
	}
}
