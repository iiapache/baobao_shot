package engagement

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/feed-svc/internal/auditclient"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/store"
	"github.com/baobao/feed-svc/internal/wspush"
)

func newTestService(t *testing.T) (*Service, *store.MemoryStore, *wspush.Stub) {
	t.Helper()
	mem := store.NewMemoryStore()
	push := wspush.NewStub()
	svc := NewService(mem, auditclient.NewStub(), nil, push)
	fixed := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return fixed }
	svc.newID = func() string { return "cmt_test_1" }
	return svc, mem, push
}

func seedPublishedPost(t *testing.T, st *store.MemoryStore, postID, ownerID, familyID string) {
	t.Helper()
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	if _, err := st.CreatePost(ctx, store.CreatePostInput{
		ID: postID, FamilyID: familyID, OwnerUserID: ownerID,
		Status: model.PostStatusPublished, Visibility: model.VisibilityFamily, CreatedAt: now,
	}); err != nil {
		t.Fatal(err)
	}
}

func TestLikeHappyPath(t *testing.T) {
	svc, mem, push := newTestService(t)
	ctx := context.Background()
	seedPublishedPost(t, mem, "post_like", "usr_owner", "fam_1")

	out, err := svc.Like(ctx, "usr_like", "post_like")
	if err != nil {
		t.Fatalf("Like() error = %v", err)
	}
	if out.Duplicate || out.PostID != "post_like" {
		t.Fatalf("out = %+v", out)
	}
	events := push.Events()
	if len(events) != 1 || events[0].Kind != wspush.KindLikeAdded {
		t.Fatalf("events = %+v", events)
	}
}

func TestLikeIdempotentDuplicate(t *testing.T) {
	svc, mem, push := newTestService(t)
	ctx := context.Background()
	seedPublishedPost(t, mem, "post_dup", "usr_owner", "fam_1")

	if _, err := svc.Like(ctx, "usr_like", "post_dup"); err != nil {
		t.Fatal(err)
	}
	out, err := svc.Like(ctx, "usr_like", "post_dup")
	if err != nil {
		t.Fatalf("second Like() error = %v", err)
	}
	if !out.Duplicate {
		t.Fatalf("duplicate = false, want true")
	}
	if len(push.Events()) != 1 {
		t.Fatalf("duplicate like should not publish again, events = %d", len(push.Events()))
	}
}

func TestUnlikeIdempotentMissing(t *testing.T) {
	svc, mem, push := newTestService(t)
	ctx := context.Background()
	seedPublishedPost(t, mem, "post_unlike", "usr_owner", "fam_1")

	out, err := svc.Unlike(ctx, "usr_like", "post_unlike")
	if err != nil {
		t.Fatalf("Unlike() error = %v", err)
	}
	if !out.Removed {
		t.Fatalf("removed = false")
	}
	if len(push.Events()) != 0 {
		t.Fatalf("missing unlike should not publish, events = %+v", push.Events())
	}
}

func TestCreateCommentHappyPath(t *testing.T) {
	svc, mem, push := newTestService(t)
	ctx := context.Background()
	seedPublishedPost(t, mem, "post_cmt", "usr_owner", "fam_1")

	out, err := svc.CreateComment(ctx, CreateCommentInput{
		UserID: "usr_cmt", Region: "cn", PostID: "post_cmt", Text: "好可爱",
	})
	if err != nil {
		t.Fatalf("CreateComment() error = %v", err)
	}
	if out.CommentID != "cmt_test_1" || out.Text != "好可爱" {
		t.Fatalf("out = %+v", out)
	}
	events := push.Events()
	if len(events) != 1 || events[0].Kind != wspush.KindCommentAdded {
		t.Fatalf("events = %+v", events)
	}
}

func TestCreateCommentRejectedByAudit(t *testing.T) {
	svc, mem, _ := newTestService(t)
	ctx := context.Background()
	seedPublishedPost(t, mem, "post_reject", "usr_owner", "fam_1")

	_, err := svc.CreateComment(ctx, CreateCommentInput{
		UserID: "usr_cmt", Region: "cn", PostID: "post_reject", Text: "reject_spam 广告",
	})
	if err != ErrAuditRejected {
		t.Fatalf("err = %v, want audit rejected", err)
	}
}

func TestDeleteCommentByAuthor(t *testing.T) {
	svc, mem, push := newTestService(t)
	ctx := context.Background()
	seedPublishedPost(t, mem, "post_del", "usr_owner", "fam_1")

	created, err := svc.CreateComment(ctx, CreateCommentInput{
		UserID: "usr_cmt", Region: "cn", PostID: "post_del", Text: "待删",
	})
	if err != nil {
		t.Fatal(err)
	}
	push.Reset()

	out, err := svc.DeleteComment(ctx, "usr_cmt", "post_del", created.CommentID)
	if err != nil {
		t.Fatalf("DeleteComment() error = %v", err)
	}
	if !out.Removed {
		t.Fatalf("removed = false")
	}
	events := push.Events()
	if len(events) != 1 || events[0].Kind != wspush.KindCommentRemoved {
		t.Fatalf("events = %+v", events)
	}
}

func TestDeleteCommentForbiddenForOtherUser(t *testing.T) {
	svc, mem, _ := newTestService(t)
	ctx := context.Background()
	seedPublishedPost(t, mem, "post_forbid", "usr_owner", "fam_1")

	created, err := svc.CreateComment(ctx, CreateCommentInput{
		UserID: "usr_cmt", Region: "cn", PostID: "post_forbid", Text: "别人的",
	})
	if err != nil {
		t.Fatal(err)
	}

	_, err = svc.DeleteComment(ctx, "usr_other", "post_forbid", created.CommentID)
	if err != ErrForbidden {
		t.Fatalf("err = %v, want forbidden", err)
	}
}

func TestDeleteCommentAllowedForPostOwner(t *testing.T) {
	svc, mem, _ := newTestService(t)
	ctx := context.Background()
	seedPublishedPost(t, mem, "post_owner_del", "usr_owner", "fam_1")

	created, err := svc.CreateComment(ctx, CreateCommentInput{
		UserID: "usr_cmt", Region: "cn", PostID: "post_owner_del", Text: "owner can delete",
	})
	if err != nil {
		t.Fatal(err)
	}

	out, err := svc.DeleteComment(ctx, "usr_owner", "post_owner_del", created.CommentID)
	if err != nil {
		t.Fatalf("DeleteComment() error = %v", err)
	}
	if !out.Removed {
		t.Fatalf("removed = false")
	}
}
