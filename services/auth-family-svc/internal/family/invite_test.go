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

func newInviteService(mem *store.MemoryStore) *family.Service {
	return family.NewService(mem, "baobao://invite", "test-secret")
}

func TestCreateInvitationAdminOnly(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := newInviteService(mem)
	ctx := context.Background()

	adminID := "usr_admin"
	f, _, err := svc.CreateFamily(ctx, adminID, "家", "cn")
	if err != nil {
		t.Fatal(err)
	}

	_, _, err = svc.CreateInvitation(ctx, f.ID, "usr_other")
	if !errors.Is(err, family.ErrNotFound) {
		t.Fatalf("non-member err = %v, want ErrNotFound", err)
	}

	if err := mem.AddMembership(ctx, model.Membership{
		UserID: "usr_member", FamilyID: f.ID, Role: model.MemberRoleFamily,
	}); err != nil {
		t.Fatal(err)
	}
	_, _, err = svc.CreateInvitation(ctx, f.ID, "usr_member")
	if !errors.Is(err, family.ErrNotAdmin) {
		t.Fatalf("member err = %v, want ErrNotAdmin", err)
	}

	invite, payload, err := svc.CreateInvitation(ctx, f.ID, adminID)
	if err != nil {
		t.Fatal(err)
	}
	if len(invite.Code) != family.InviteCodeLength {
		t.Fatalf("code len = %d, want %d", len(invite.Code), family.InviteCodeLength)
	}
	if invite.MaxUses != family.InviteMaxUses {
		t.Fatalf("maxUses = %d, want %d", invite.MaxUses, family.InviteMaxUses)
	}
	if payload.Code != invite.Code || payload.Scheme != "baobao://invite" {
		t.Fatalf("payload = %+v", payload)
	}
	if !family.VerifyInvitePayload(payload, "test-secret") {
		t.Fatal("invalid qr payload signature")
	}
}

func TestJoinViaInvitationSuccess(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := newInviteService(mem)
	ctx := context.Background()

	adminID := "usr_admin"
	joinerID := "usr_joiner"
	f, _, err := svc.CreateFamily(ctx, adminID, "家", "cn")
	if err != nil {
		t.Fatal(err)
	}

	invite, _, err := svc.CreateInvitation(ctx, f.ID, adminID)
	if err != nil {
		t.Fatal(err)
	}

	result, err := svc.JoinViaInvitation(ctx, invite.Code, joinerID, "grandma", "外婆")
	if err != nil {
		t.Fatal(err)
	}
	if result.FamilyID != f.ID || result.Role != model.MemberRoleFamily {
		t.Fatalf("result = %+v", result)
	}

	detail, err := svc.GetDetail(ctx, f.ID, joinerID)
	if err != nil {
		t.Fatal(err)
	}
	if len(detail.Members) != 2 {
		t.Fatalf("members = %d, want 2", len(detail.Members))
	}
}

func TestJoinViaInvitationExpired(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := newInviteService(mem)
	ctx := context.Background()

	f, _, err := svc.CreateFamily(ctx, "usr_admin", "家", "cn")
	if err != nil {
		t.Fatal(err)
	}

	invite, err := mem.CreateInviteCode(ctx, store.CreateInviteCodeInput{
		Code: "123456", FamilyID: f.ID, CreatedBy: "usr_admin",
		ExpireAt: time.Now().UTC().Add(-time.Hour), MaxUses: family.InviteMaxUses,
	})
	if err != nil {
		t.Fatal(err)
	}

	_, err = svc.JoinViaInvitation(ctx, invite.Code, "usr_joiner", "dad", "")
	if !errors.Is(err, family.ErrInviteExpired) {
		t.Fatalf("err = %v, want ErrInviteExpired", err)
	}
}

func TestJoinViaInvitationUsedUp(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := newInviteService(mem)
	ctx := context.Background()

	f, _, err := svc.CreateFamily(ctx, "usr_admin", "家", "cn")
	if err != nil {
		t.Fatal(err)
	}

	invite, err := mem.CreateInviteCode(ctx, store.CreateInviteCodeInput{
		Code: "654321", FamilyID: f.ID, CreatedBy: "usr_admin",
		ExpireAt: time.Now().UTC().Add(family.InviteTTL), MaxUses: 1,
	})
	if err != nil {
		t.Fatal(err)
	}

	if _, err := svc.JoinViaInvitation(ctx, invite.Code, "usr_first", "mom", ""); err != nil {
		t.Fatalf("first join: %v", err)
	}

	_, err = svc.JoinViaInvitation(ctx, invite.Code, "usr_joiner", "dad", "")
	if !errors.Is(err, family.ErrInviteUsedUp) {
		t.Fatalf("err = %v, want ErrInviteUsedUp", err)
	}
}

func TestJoinViaInvitationJoinLimit(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := newInviteService(mem)
	ctx := context.Background()

	joinerID := "usr_join_limit"
	for i := 0; i < family.MaxFamiliesJoined; i++ {
		owner := "owner_" + string(rune('A'+i))
		familyID := "fam_seed_" + string(rune('A'+i))
		if _, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
			ID: familyID, Name: "x", AdminUserID: owner, Region: "cn",
		}); err != nil {
			t.Fatal(err)
		}
		if err := mem.AddMembership(ctx, model.Membership{
			UserID: joinerID, FamilyID: familyID, Role: model.MemberRoleFamily,
		}); err != nil {
			t.Fatal(err)
		}
	}

	f, _, err := svc.CreateFamily(ctx, "usr_admin", "新家庭", "cn")
	if err != nil {
		t.Fatal(err)
	}
	invite, _, err := svc.CreateInvitation(ctx, f.ID, "usr_admin")
	if err != nil {
		t.Fatal(err)
	}

	_, err = svc.JoinViaInvitation(ctx, invite.Code, joinerID, "uncle", "")
	if !errors.Is(err, family.ErrJoinLimit) {
		t.Fatalf("err = %v, want ErrJoinLimit", err)
	}
}

func TestRevokeInvitation(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := newInviteService(mem)
	ctx := context.Background()

	f, _, err := svc.CreateFamily(ctx, "usr_admin", "家", "cn")
	if err != nil {
		t.Fatal(err)
	}
	invite, _, err := svc.CreateInvitation(ctx, f.ID, "usr_admin")
	if err != nil {
		t.Fatal(err)
	}

	if err := svc.RevokeInvitation(ctx, f.ID, "usr_admin", invite.Code); err != nil {
		t.Fatal(err)
	}

	_, err = svc.JoinViaInvitation(ctx, invite.Code, "usr_joiner", "aunt", "")
	if !errors.Is(err, family.ErrInviteExpired) {
		t.Fatalf("err = %v, want ErrInviteExpired after revoke", err)
	}
}
