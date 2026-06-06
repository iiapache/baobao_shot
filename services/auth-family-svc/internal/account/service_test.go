package account

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/store"
)

func TestRequestDeletionIdempotent(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem)
	svc.now = func() time.Time { return time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC) }

	userID := "usr_del_idempotent"
	if _, err := mem.CreateUser(context.Background(), store.CreateUserInput{
		ID: userID, AppleSub: "apple-del", Region: "cn", Nickname: "用户",
	}); err != nil {
		t.Fatal(err)
	}

	first, err := svc.RequestDeletion(context.Background(), userID)
	if err != nil {
		t.Fatalf("first request: %v", err)
	}
	second, err := svc.RequestDeletion(context.Background(), userID)
	if err != nil {
		t.Fatalf("second request: %v", err)
	}
	if !first.ScheduledAt.Equal(second.ScheduledAt) {
		t.Fatalf("scheduledAt mismatch: %v vs %v", first.ScheduledAt, second.ScheduledAt)
	}
	if first.ScheduledAt.Sub(first.RequestedAt) != DeletionGracePeriod {
		t.Fatalf("grace period = %v, want %v", first.ScheduledAt.Sub(first.RequestedAt), DeletionGracePeriod)
	}
}

func TestCancelDeletionWithinGracePeriod(t *testing.T) {
	mem := store.NewMemoryStore()
	base := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	svc := NewService(mem)
	svc.now = func() time.Time { return base }

	userID := "usr_cancel_ok"
	if _, err := mem.CreateUser(context.Background(), store.CreateUserInput{
		ID: userID, AppleSub: "apple-cancel", Region: "cn", Nickname: "用户",
	}); err != nil {
		t.Fatal(err)
	}

	if _, err := svc.RequestDeletion(context.Background(), userID); err != nil {
		t.Fatal(err)
	}
	if _, err := mem.FindByID(context.Background(), userID); err == nil {
		t.Fatal("user should be soft-deleted")
	}

	result, err := svc.CancelDeletion(context.Background(), userID)
	if err != nil {
		t.Fatalf("cancel: %v", err)
	}
	if !result.Restored {
		t.Fatal("expected restored=true")
	}
	if _, err := mem.FindByID(context.Background(), userID); err != nil {
		t.Fatalf("user should be restored: %v", err)
	}
}

func TestCancelDeletionAfterGracePeriod(t *testing.T) {
	mem := store.NewMemoryStore()
	requestedAt := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	expiredAt := requestedAt.Add(DeletionGracePeriod + time.Hour)
	svc := NewService(mem)
	svc.now = func() time.Time { return requestedAt }

	userID := "usr_cancel_expired"
	if _, err := mem.CreateUser(context.Background(), store.CreateUserInput{
		ID: userID, AppleSub: "apple-expired", Region: "cn", Nickname: "用户",
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.RequestDeletion(context.Background(), userID); err != nil {
		t.Fatal(err)
	}

	svc.now = func() time.Time { return expiredAt }
	if _, err := svc.CancelDeletion(context.Background(), userID); err == nil {
		t.Fatal("expected error after grace period")
	} else if !errors.Is(err, ErrDeletionExpired) {
		t.Fatalf("got %v, want ErrDeletionExpired", err)
	}
}

func TestProcessDueHardDeletions(t *testing.T) {
	mem := store.NewMemoryStore()
	requestedAt := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	dueAt := requestedAt.Add(DeletionGracePeriod + time.Minute)
	svc := NewService(mem)
	svc.now = func() time.Time { return requestedAt }

	userID := "usr_hard_delete"
	if _, err := mem.CreateUser(context.Background(), store.CreateUserInput{
		ID: userID, AppleSub: "apple-hard", Region: "cn", Nickname: "用户",
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.RequestDeletion(context.Background(), userID); err != nil {
		t.Fatal(err)
	}

	svc.now = func() time.Time { return dueAt }
	n, err := svc.ProcessDueHardDeletions(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("processed = %d, want 1", n)
	}

	record, err := mem.GetDeletion(context.Background(), userID)
	if err != nil {
		t.Fatal(err)
	}
	if record.CompletedAt == nil {
		t.Fatal("expected completed_at to be set")
	}
}

func TestRequestExportIdempotent(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem)

	userID := "usr_export"
	if _, err := mem.CreateUser(context.Background(), store.CreateUserInput{
		ID: userID, AppleSub: "apple-export", Region: "cn", Nickname: "用户",
	}); err != nil {
		t.Fatal(err)
	}

	first, err := svc.RequestExport(context.Background(), userID)
	if err != nil {
		t.Fatal(err)
	}
	second, err := svc.RequestExport(context.Background(), userID)
	if err != nil {
		t.Fatal(err)
	}
	if first.ExportID != second.ExportID {
		t.Fatalf("exportId mismatch: %s vs %s", first.ExportID, second.ExportID)
	}
	if first.Status != "pending" {
		t.Fatalf("status = %q, want pending", first.Status)
	}
}
