package family_test

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/family"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestTakeoverSchedulerRunOnce(t *testing.T) {
	mem := store.NewMemoryStore()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	svc := family.NewService(mem, "", "")
	svc.SetNowForTest(now)
	scheduler := family.NewScheduler(svc, time.Hour)
	ctx := context.Background()

	adminID := "usr_sched_admin"
	memberID := "usr_sched_member"
	seedTakeoverUsers(t, mem, adminID, memberID)

	f, _, err := svc.CreateFamily(ctx, adminID, "调度测试家", "cn")
	if err != nil {
		t.Fatal(err)
	}
	if err := mem.AddMembership(ctx, model.Membership{
		UserID: memberID, FamilyID: f.ID, Role: model.MemberRoleFamily,
	}); err != nil {
		t.Fatal(err)
	}
	if err := mem.SetUserLastSeen(ctx, adminID, now.Add(-31*24*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Takeover(ctx, f.ID, memberID, family.TakeoverInput{}); err != nil {
		t.Fatal(err)
	}

	svc.SetNowForTest(now.Add(8 * 24 * time.Hour))
	n, err := scheduler.RunOnce(ctx)
	if err != nil || n != 1 {
		t.Fatalf("RunOnce n=%d err=%v", n, err)
	}
}
