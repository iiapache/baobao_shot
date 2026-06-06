package family_test

import (
	"context"
	"errors"
	"testing"

	"github.com/baobao/auth-family-svc/internal/family"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestTransferAdminSuccess(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := family.NewService(mem, "", "")
	ctx := context.Background()

	adminID := "usr_admin_transfer"
	targetID := "usr_target_transfer"
	seedTransferUsers(t, mem, adminID, targetID)

	f, _, err := svc.CreateFamily(ctx, adminID, "转让测试家", "cn")
	if err != nil {
		t.Fatal(err)
	}
	if err := mem.AddMembership(ctx, model.Membership{
		UserID: targetID, FamilyID: f.ID, Role: model.MemberRoleFamily, Nickname: "爸爸",
	}); err != nil {
		t.Fatal(err)
	}

	result, err := svc.TransferAdmin(ctx, f.ID, adminID, targetID)
	if err != nil {
		t.Fatalf("TransferAdmin: %v", err)
	}
	if result.NewAdminUserID != targetID || result.PreviousAdminUserID != adminID {
		t.Fatalf("unexpected result: %+v", result)
	}

	detail, err := mem.GetFamilyDetail(ctx, f.ID, targetID)
	if err != nil {
		t.Fatal(err)
	}
	if detail.Family.AdminUserID != targetID || detail.Role != model.MemberRoleAdmin {
		t.Fatalf("target not admin: %+v", detail)
	}
}

func TestTransferAdminRejectsGuestTarget(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := family.NewService(mem, "", "")
	ctx := context.Background()

	adminID := "usr_admin_guest_target"
	guestID := "usr_guest_target"
	seedTransferUsers(t, mem, adminID, guestID)

	f, _, err := svc.CreateFamily(ctx, adminID, "家", "cn")
	if err != nil {
		t.Fatal(err)
	}
	if err := mem.AddMembership(ctx, model.Membership{
		UserID: guestID, FamilyID: f.ID, Role: model.MemberRoleGuest,
	}); err != nil {
		t.Fatal(err)
	}

	_, err = svc.TransferAdmin(ctx, f.ID, adminID, guestID)
	if !errors.Is(err, family.ErrTransferTargetInvalid) {
		t.Fatalf("err = %v, want ErrTransferTargetInvalid", err)
	}
}

func seedTransferUsers(t *testing.T, mem *store.MemoryStore, ids ...string) {
	t.Helper()
	for _, id := range ids {
		if _, err := mem.CreateUser(context.Background(), store.CreateUserInput{
			ID: id, AppleSub: "apple-" + id, Region: "cn", Nickname: id,
		}); err != nil {
			t.Fatalf("seed user %s: %v", id, err)
		}
	}
}
