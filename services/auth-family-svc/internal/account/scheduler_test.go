package account

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/store"
)

func TestSchedulerRunOnce(t *testing.T) {
	mem := store.NewMemoryStore()
	requestedAt := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	dueAt := requestedAt.Add(DeletionGracePeriod + time.Minute)
	svc := NewService(mem)
	svc.now = func() time.Time { return dueAt }

	userID := "usr_scheduler"
	if _, err := mem.CreateUser(context.Background(), store.CreateUserInput{
		ID: userID, AppleSub: "apple-sched", Region: "cn", Nickname: "用户",
	}); err != nil {
		t.Fatal(err)
	}
	svc.now = func() time.Time { return requestedAt }
	if _, err := svc.RequestDeletion(context.Background(), userID); err != nil {
		t.Fatal(err)
	}

	svc.now = func() time.Time { return dueAt }
	scheduler := NewScheduler(svc, time.Hour)
	n, err := scheduler.RunOnce(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("processed = %d, want 1", n)
	}
}
