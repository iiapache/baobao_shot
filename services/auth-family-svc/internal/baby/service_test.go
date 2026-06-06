package baby_test

import (
	"context"
	"testing"

	"github.com/baobao/auth-family-svc/internal/baby"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestServiceCreateListSoftDelete(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()

	family, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_baby_svc", Name: "家", AdminUserID: "usr_admin", Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}

	svc := baby.NewService(mem)
	created, err := svc.Create(ctx, baby.CreateInput{
		FamilyID: family.ID,
		UserID:   "usr_admin",
		Name:     "小宝",
		Gender:   "male",
		Birthday: "2026-01-15",
		DeviceTZ: "Asia/Shanghai",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if created.Timezone != "Asia/Shanghai" {
		t.Fatalf("timezone = %q", created.Timezone)
	}

	place := "北京"
	second, err := svc.Create(ctx, baby.CreateInput{
		FamilyID:   family.ID,
		UserID:     "usr_admin",
		Name:       "二宝",
		Gender:     "female",
		Birthday:   "2026-02-01",
		BirthPlace: &place,
	})
	if err != nil {
		t.Fatalf("create second: %v", err)
	}
	if second.Timezone != "Asia/Shanghai" {
		t.Fatalf("birth place timezone = %q", second.Timezone)
	}

	items, err := svc.ListByFamily(ctx, family.ID, "usr_admin")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 2 {
		t.Fatalf("list len = %d, want 2", len(items))
	}

	if err := svc.Delete(ctx, created.ID, "usr_admin"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := svc.Get(ctx, created.ID, "usr_admin"); err == nil {
		t.Fatal("expected deleted baby to be not found")
	}

	items, err = svc.ListByFamily(ctx, family.ID, "usr_admin")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 {
		t.Fatalf("after delete len = %d, want 1", len(items))
	}
}

func TestServiceCreateRequiresMembership(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	family, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_member_only", Name: "家", AdminUserID: "usr_admin", Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}

	svc := baby.NewService(mem)
	_, err = svc.Create(ctx, baby.CreateInput{
		FamilyID: family.ID,
		UserID:   "usr_outsider",
		Name:     "小宝",
		Birthday: "2026-01-15",
	})
	if err != baby.ErrNotMember {
		t.Fatalf("err = %v, want ErrNotMember", err)
	}
}

func TestServiceUpdateBirthPlaceChangesTimezone(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	family, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_tz_update", Name: "家", AdminUserID: "usr_admin", Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}

	svc := baby.NewService(mem)
	created, err := svc.Create(ctx, baby.CreateInput{
		FamilyID: family.ID,
		UserID:   "usr_admin",
		Name:     "小宝",
		Birthday: "2026-01-15",
		DeviceTZ: "UTC",
	})
	if err != nil {
		t.Fatal(err)
	}

	place := "纽约"
	updated, err := svc.Update(ctx, baby.UpdateInput{
		BabyID:     created.ID,
		UserID:     "usr_admin",
		BirthPlace: &place,
	})
	if err != nil {
		t.Fatal(err)
	}
	if updated.Timezone != "America/New_York" {
		t.Fatalf("timezone = %q, want America/New_York", updated.Timezone)
	}
}

func TestServiceInvalidGender(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	family, _ := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_invalid", Name: "家", AdminUserID: "usr_admin", Region: "cn",
	})
	svc := baby.NewService(mem)
	_, err := svc.Create(ctx, baby.CreateInput{
		FamilyID: family.ID,
		UserID:   "usr_admin",
		Name:     "小宝",
		Gender:   "other",
		Birthday: "2026-01-15",
	})
	if err != baby.ErrInvalidGender {
		t.Fatalf("err = %v", err)
	}
}

func TestServiceFamilyIDForBaby(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	family, _ := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_lookup", Name: "家", AdminUserID: "usr_admin", Region: "cn",
	})
	svc := baby.NewService(mem)
	created, _ := svc.Create(ctx, baby.CreateInput{
		FamilyID: family.ID,
		UserID:   "usr_admin",
		Name:     "小宝",
		Birthday: "2026-01-15",
	})
	familyID, err := svc.FamilyIDForBaby(ctx, created.ID)
	if err != nil || familyID != family.ID {
		t.Fatalf("familyID = %q err = %v", familyID, err)
	}

	if err := svc.Delete(ctx, created.ID, "usr_admin"); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.FamilyIDForBaby(ctx, created.ID); err != baby.ErrNotFound {
		t.Fatalf("deleted lookup err = %v", err)
	}
}

// ensure model import is used for compile-time checks
var _ model.BabyGender = model.BabyGenderMale
