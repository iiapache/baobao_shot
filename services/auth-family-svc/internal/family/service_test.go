package family_test

import (
	"context"
	"errors"
	"testing"

	"github.com/baobao/auth-family-svc/internal/family"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestServiceCreateLimit(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := family.NewService(mem, "", "")
	ctx := context.Background()
	userID := "usr_svc_create"

	for i := 0; i < family.MaxFamiliesCreated; i++ {
		if _, _, err := svc.CreateFamily(ctx, userID, "家", "cn"); err != nil {
			t.Fatalf("create #%d: %v", i+1, err)
		}
	}

	_, _, err := svc.CreateFamily(ctx, userID, "超限", "cn")
	if !errors.Is(err, family.ErrCreateLimit) {
		t.Fatalf("err = %v, want ErrCreateLimit", err)
	}
}

func TestServiceJoinLimit(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := family.NewService(mem, "", "")
	ctx := context.Background()
	userID := "usr_svc_join"

	for i := 0; i < family.MaxFamiliesJoined; i++ {
		owner := "owner_" + string(rune('A'+i))
		familyID := "fam_join_" + string(rune('A'+i))
		if _, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
			ID: familyID, Name: "x", AdminUserID: owner, Region: "cn",
		}); err != nil {
			t.Fatal(err)
		}
		if err := mem.AddMembership(ctx, model.Membership{
			UserID: userID, FamilyID: familyID, Role: model.MemberRoleFamily,
		}); err != nil {
			t.Fatal(err)
		}
	}

	if err := svc.CheckJoinLimit(ctx, userID); !errors.Is(err, family.ErrJoinLimit) {
		t.Fatalf("CheckJoinLimit err = %v, want ErrJoinLimit", err)
	}

	_, _, err := svc.CreateFamily(ctx, userID, "新家庭", "cn")
	if !errors.Is(err, family.ErrJoinLimit) {
		t.Fatalf("CreateFamily err = %v, want ErrJoinLimit", err)
	}
}
