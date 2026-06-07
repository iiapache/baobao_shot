package post

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/feed-svc/internal/auditclient"
	"github.com/baobao/feed-svc/internal/mediaclient"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/ratelimit"
	"github.com/baobao/feed-svc/internal/store"
)

func newTestService(t *testing.T) (*Service, *store.MemoryStore, *auditclient.Stub) {
	t.Helper()
	mem := store.NewMemoryStore()
	audit := auditclient.NewStub()
	svc := NewService(mem, audit, ratelimit.NewSlidingWindow(), nil)
	fixed := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return fixed }
	return svc, mem, audit
}

func baseCreateInput() CreateInput {
	return CreateInput{
		UserID:     "usr_1",
		Region:     "cn",
		FamilyID:   "fam_1",
		BabyIDs:    []string{"bb_1"},
		Caption:    "豆豆 · 第 312 天",
		Visibility: model.VisibilityFamily,
	}
}

func TestCreateHappyTextOnlyPublished(t *testing.T) {
	svc, mem, _ := newTestService(t)
	ctx := context.Background()

	out, err := svc.Create(ctx, baseCreateInput())
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if out.Status != model.PostStatusPublished {
		t.Fatalf("status = %s, want published", out.Status)
	}

	post, err := mem.GetPost(ctx, out.PostID)
	if err != nil {
		t.Fatal(err)
	}
	if post.Status != model.PostStatusPublished {
		t.Fatalf("stored status = %s", post.Status)
	}
}

func TestCreateHappyWithMediaAuditStatus(t *testing.T) {
	svc, mem, audit := newTestService(t)
	ctx := context.Background()

	in := baseCreateInput()
	in.Items = []CreateItemInput{{
		Kind: model.ItemKindImage, ObjectKey: "family/fam_1/post/1.heic",
		Width: 1024, Height: 1024,
	}}

	out, err := svc.Create(ctx, in)
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if out.Status != model.PostStatusAudit {
		t.Fatalf("status = %s, want audit", out.Status)
	}
	if audit.PendingCount() != 1 {
		t.Fatalf("pending media audits = %d, want 1", audit.PendingCount())
	}

	items, err := mem.ListPostItems(ctx, out.PostID)
	if err != nil || len(items) != 1 {
		t.Fatalf("items = %+v err = %v", items, err)
	}
}

func TestCreateTextRejectedBlocksPublish(t *testing.T) {
	svc, mem, _ := newTestService(t)
	ctx := context.Background()

	in := baseCreateInput()
	in.Caption = "reject_spam 广告文案"

	_, err := svc.Create(ctx, in)
	if err != ErrAuditRejected {
		t.Fatalf("Create() error = %v, want ErrAuditRejected", err)
	}

	okInput := baseCreateInput()
	okInput.Caption = "clean caption"
	out, err := svc.Create(ctx, okInput)
	if err != nil {
		t.Fatalf("publish after reject should still work: %v", err)
	}
	post, err := mem.GetPost(ctx, out.PostID)
	if err != nil || post.Caption != "clean caption" {
		t.Fatalf("post = %+v err = %v", post, err)
	}
}

func TestCreateRateLimited(t *testing.T) {
	svc, _, _ := newTestService(t)
	ctx := context.Background()
	in := baseCreateInput()

	for i := 0; i < 5; i++ {
		if _, err := svc.Create(ctx, in); err != nil {
			t.Fatalf("Create #%d error = %v", i+1, err)
		}
	}
	if _, err := svc.Create(ctx, in); err != ErrRateLimited {
		t.Fatalf("6th Create() error = %v, want ErrRateLimited", err)
	}
}

func TestCompleteMediaAuditTransitions(t *testing.T) {
	svc, mem, audit := newTestService(t)
	ctx := context.Background()

	in := baseCreateInput()
	in.Items = []CreateItemInput{{
		Kind: model.ItemKindImage, ObjectKey: "family/fam_1/post/pass.heic",
		Width: 100, Height: 100,
	}}
	out, err := svc.Create(ctx, in)
	if err != nil {
		t.Fatal(err)
	}

	// simulate async pass -> published
	if err := svc.CompleteMediaAudit(ctx, out.PostID, true); err != nil {
		t.Fatal(err)
	}
	post, err := mem.GetPost(ctx, out.PostID)
	if err != nil || post.Status != model.PostStatusPublished {
		t.Fatalf("after pass: post = %+v err = %v", post, err)
	}

	// new post with reject marker in object key
	in.Items[0].ObjectKey = "family/fam_1/post/reject_porn.heic"
	out2, err := svc.Create(ctx, in)
	if err != nil {
		t.Fatal(err)
	}
	jobs := audit.PendingCount()
	if jobs < 2 {
		t.Fatalf("expected pending jobs >= 2, got %d", jobs)
	}

	if err := svc.CompleteMediaAudit(ctx, out2.PostID, false); err != nil {
		t.Fatal(err)
	}
	if _, err := mem.GetPost(ctx, out2.PostID); err != store.ErrNotFound {
		t.Fatalf("rejected media should remove post, err = %v", err)
	}
}

func TestDeleteWithdrawsPostAndEnqueuesOSS(t *testing.T) {
	svc, mem, _ := newTestService(t)
	media := mediaclient.NewStub()
	svc.media = media
	ctx := context.Background()

	in := baseCreateInput()
	thumb := "family/fam_1/post/thumb.heic"
	in.Items = []CreateItemInput{{
		Kind: model.ItemKindImage, ObjectKey: "family/fam_1/post/1.heic",
		Width: 100, Height: 100, ThumbnailKey: &thumb,
	}}
	out, err := svc.Create(ctx, in)
	if err != nil {
		t.Fatal(err)
	}

	del, err := svc.Delete(ctx, in.UserID, out.PostID, in.Region)
	if err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	if del.Status != model.PostStatusRemoved {
		t.Fatalf("status = %s", del.Status)
	}
	if _, err := mem.GetPost(ctx, out.PostID); err != store.ErrNotFound {
		t.Fatalf("post should be soft-deleted, err = %v", err)
	}
	items, err := mem.ListPostItems(ctx, out.PostID)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 0 {
		t.Fatalf("items should be hidden after withdraw, got %d", len(items))
	}
	if media.PendingCount() != 2 {
		t.Fatalf("oss pending = %d, want 2", media.PendingCount())
	}
}

func TestDeleteForbiddenForNonOwner(t *testing.T) {
	svc, _, _ := newTestService(t)
	ctx := context.Background()

	out, err := svc.Create(ctx, baseCreateInput())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Delete(ctx, "usr_other", out.PostID, "cn"); err != ErrForbidden {
		t.Fatalf("Delete() error = %v, want ErrForbidden", err)
	}
}

func TestDeleteNotFound(t *testing.T) {
	svc, _, _ := newTestService(t)
	if _, err := svc.Delete(context.Background(), "usr_1", "pst_missing", "cn"); err != ErrNotFound {
		t.Fatalf("Delete() error = %v, want ErrNotFound", err)
	}
}
