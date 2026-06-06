package family_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/family"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestTakeoverFullFlow(t *testing.T) {
	mem := store.NewMemoryStore()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	svc := family.NewService(mem, "", "")
	svc.SetNowForTest(now)
	ctx := context.Background()

	adminID := "usr_admin_takeover"
	member1 := "usr_member_takeover_1"
	member2 := "usr_member_takeover_2"
	member3 := "usr_member_takeover_3"
	seedTakeoverUsers(t, mem, adminID, member1, member2, member3)

	f, _, err := svc.CreateFamily(ctx, adminID, "接管测试家", "cn")
	if err != nil {
		t.Fatal(err)
	}
	for _, memberID := range []string{member1, member2, member3} {
		if err := mem.AddMembership(ctx, model.Membership{
			UserID: memberID, FamilyID: f.ID, Role: model.MemberRoleFamily,
		}); err != nil {
			t.Fatal(err)
		}
	}

	inactiveAt := now.Add(-31 * 24 * time.Hour)
	if err := mem.SetUserLastSeen(ctx, adminID, inactiveAt); err != nil {
		t.Fatal(err)
	}

	result, err := svc.Takeover(ctx, f.ID, member1, family.TakeoverInput{})
	if err != nil {
		t.Fatalf("initiate takeover: %v", err)
	}
	if result.Status != string(model.TakeoverStatusVoting) || result.ApproveCount != 1 || result.RequiredApprovals != 2 {
		t.Fatalf("unexpected initiate result: %+v", result)
	}

	result, err = svc.Takeover(ctx, f.ID, member2, family.TakeoverInput{Choice: "approve"})
	if err != nil {
		t.Fatalf("second vote: %v", err)
	}
	if result.Status != string(model.TakeoverStatusObjectionPeriod) || result.ApproveCount != 2 {
		t.Fatalf("expected objection period after 50%% approvals, got %+v", result)
	}
	if result.ObjectionEndsAt == "" {
		t.Fatal("objectionEndsAt should be set")
	}

	now = now.Add(8 * 24 * time.Hour)
	svc.SetNowForTest(now)
	n, err := svc.ProcessDueTakeovers(ctx)
	if err != nil || n != 1 {
		t.Fatalf("ProcessDueTakeovers n=%d err=%v", n, err)
	}

	detail, err := mem.GetFamilyDetail(ctx, f.ID, member1)
	if err != nil {
		t.Fatal(err)
	}
	if detail.Family.AdminUserID != member1 || detail.Role != model.MemberRoleAdmin {
		t.Fatalf("initiator not admin after completion: %+v", detail)
	}
}

func TestTakeoverAdminCanObjectDuringObjectionPeriod(t *testing.T) {
	mem := store.NewMemoryStore()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	svc := family.NewService(mem, "", "")
	svc.SetNowForTest(now)
	ctx := context.Background()

	adminID := "usr_admin_object"
	memberID := "usr_member_object"
	seedTakeoverUsers(t, mem, adminID, memberID)

	f, _, err := svc.CreateFamily(ctx, adminID, "异议测试家", "cn")
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
		t.Fatalf("initiate: %v", err)
	}

	result, err := svc.Takeover(ctx, f.ID, adminID, family.TakeoverInput{})
	if err != nil {
		t.Fatalf("admin object: %v", err)
	}
	if result.Status != string(model.TakeoverStatusCancelled) {
		t.Fatalf("status = %q, want cancelled", result.Status)
	}

	detail, err := mem.GetFamilyDetail(ctx, f.ID, adminID)
	if err != nil {
		t.Fatal(err)
	}
	if detail.Family.AdminUserID != adminID {
		t.Fatalf("admin should remain admin, got %+v", detail.Family)
	}
}

func TestTakeoverRejectsActiveAdmin(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := family.NewService(mem, "", "")
	ctx := context.Background()

	adminID := "usr_admin_active"
	memberID := "usr_member_active"
	seedTakeoverUsers(t, mem, adminID, memberID)

	f, _, err := svc.CreateFamily(ctx, adminID, "活跃管理员家", "cn")
	if err != nil {
		t.Fatal(err)
	}
	if err := mem.AddMembership(ctx, model.Membership{
		UserID: memberID, FamilyID: f.ID, Role: model.MemberRoleFamily,
	}); err != nil {
		t.Fatal(err)
	}

	_, err = svc.Takeover(ctx, f.ID, memberID, family.TakeoverInput{})
	if !errors.Is(err, family.ErrAdminActive) {
		t.Fatalf("err = %v, want ErrAdminActive", err)
	}
}

func seedTakeoverUsers(t *testing.T, mem *store.MemoryStore, ids ...string) {
	t.Helper()
	for _, id := range ids {
		if _, err := mem.CreateUser(context.Background(), store.CreateUserInput{
			ID: id, AppleSub: "apple-" + id, Region: "cn", Nickname: id,
		}); err != nil {
			t.Fatalf("seed user %s: %v", id, err)
		}
	}
}
