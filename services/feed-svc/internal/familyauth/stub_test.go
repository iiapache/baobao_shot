package familyauth

import (
	"context"
	"testing"

	"github.com/baobao/feed-svc/internal/middleware"
)

func TestStubAllowsMemberWhenFamiliesPresent(t *testing.T) {
	ctx := middleware.WithFamilies(context.Background(), []middleware.FamilyClaim{
		{FamilyID: "fam_ok", Role: "guest"},
	})
	if err := NewStub().CanAccessFamilyFeed(ctx, "fam_ok"); err != nil {
		t.Fatal(err)
	}
}

func TestStubRejectsNonMember(t *testing.T) {
	ctx := middleware.WithFamilies(context.Background(), []middleware.FamilyClaim{
		{FamilyID: "fam_other", Role: "family"},
	})
	if err := NewStub().CanAccessFamilyFeed(ctx, "fam_target"); err != ErrForbidden {
		t.Fatalf("err = %v", err)
	}
}

func TestStubSkipsWhenFamiliesAbsent(t *testing.T) {
	if err := NewStub().CanAccessFamilyFeed(context.Background(), "fam_dev"); err != nil {
		t.Fatalf("dev mode should skip family check: %v", err)
	}
}
