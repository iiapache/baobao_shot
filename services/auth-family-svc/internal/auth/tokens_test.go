package auth

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestIssueAndParseAccessToken(t *testing.T) {
	issuer := NewTokenIssuer("unit-test-secret")
	pair, err := issuer.Issue(IssueTokenInput{
		UserID:   "usr_test",
		Region:   "cn",
		DeviceID: "dev-1",
		Families: []FamilyClaim{{FamilyID: "fam_1", Role: "admin"}},
	})
	if err != nil {
		t.Fatal(err)
	}

	claims, err := issuer.ParseAccess(pair.AccessToken)
	if err != nil {
		t.Fatal(err)
	}
	if claims.Subject != "usr_test" {
		t.Fatalf("sub = %q", claims.Subject)
	}
	if claims.Region != "cn" {
		t.Fatalf("region = %q", claims.Region)
	}
	if claims.Dev != "dev-1" {
		t.Fatalf("dev = %q", claims.Dev)
	}
	if claims.Typ != tokenTypeAccess {
		t.Fatalf("typ = %q", claims.Typ)
	}
	if len(claims.Families) != 1 || claims.Families[0].FamilyID != "fam_1" {
		t.Fatalf("families = %+v", claims.Families)
	}
	if !strings.HasPrefix(claims.ID, "jti_") {
		t.Fatalf("jti = %q", claims.ID)
	}
}

func TestRefreshRotationRevokesOldToken(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := newTestTokenService(mem)
	ctx := context.Background()

	pair, err := svc.IssueForUser(ctx, "usr_rotate", "cn", "dev-rotate")
	if err != nil {
		t.Fatal(err)
	}

	newPair, err := svc.Refresh(ctx, pair.RefreshToken, "dev-rotate")
	if err != nil {
		t.Fatal(err)
	}
	if newPair.AccessToken == pair.AccessToken {
		t.Fatal("expected new access token after refresh")
	}

	_, err = svc.Refresh(ctx, pair.RefreshToken, "dev-rotate")
	if err != ErrRefreshInvalid {
		t.Fatalf("old refresh reuse: got %v, want ErrRefreshInvalid", err)
	}

	_, err = svc.Refresh(ctx, newPair.RefreshToken, "dev-rotate")
	if err != nil {
		t.Fatalf("new refresh should work: %v", err)
	}
}

func TestLogoutRevokesAccessToken(t *testing.T) {
	svc := newTestTokenService(store.NewMemoryStore())
	ctx := context.Background()

	pair, err := svc.IssueForUser(ctx, "usr_logout", "cn", "dev-logout")
	if err != nil {
		t.Fatal(err)
	}

	if err := svc.Logout(ctx, pair.AccessToken); err != nil {
		t.Fatal(err)
	}

	_, err = svc.ValidateAccess(ctx, pair.AccessToken)
	if err != ErrTokenRevoked {
		t.Fatalf("revoked access: got %v, want ErrTokenRevoked", err)
	}
}

func TestRefreshDeviceMismatch(t *testing.T) {
	svc := newTestTokenService(store.NewMemoryStore())
	ctx := context.Background()

	pair, err := svc.IssueForUser(ctx, "usr_dev", "cn", "dev-a")
	if err != nil {
		t.Fatal(err)
	}

	_, err = svc.Refresh(ctx, pair.RefreshToken, "dev-b")
	if err != ErrDeviceMismatch {
		t.Fatalf("device mismatch: got %v", err)
	}
}

func TestIssueIncludesFamilyMemberships(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	userID := "usr_fam"
	_, err := mem.CreateUser(ctx, store.CreateUserInput{
		ID:       userID,
		AppleSub: "apple-fam",
		Region:   "cn",
	})
	if err != nil {
		t.Fatal(err)
	}
	family, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID:          "fam_test",
		Name:        "家",
		AdminUserID: userID,
		Region:      "cn",
	})
	if err != nil {
		t.Fatal(err)
	}
	_ = family

	svc := newTestTokenService(mem)
	pair, err := svc.IssueForUser(ctx, userID, "cn", "dev-fam")
	if err != nil {
		t.Fatal(err)
	}

	claims, err := svc.issuer.ParseAccess(pair.AccessToken)
	if err != nil {
		t.Fatal(err)
	}
	if len(claims.Families) != 1 {
		t.Fatalf("families = %+v", claims.Families)
	}
	if claims.Families[0].Role != string(model.MemberRoleAdmin) {
		t.Fatalf("role = %q", claims.Families[0].Role)
	}
}

func TestExpiredRefreshToken(t *testing.T) {
	issuer := NewTokenIssuer("expired-secret")
	issuer.now = func() time.Time {
		return time.Now().UTC().Add(-31 * 24 * time.Hour)
	}
	pair, err := issuer.Issue(IssueTokenInput{
		UserID:   "usr_exp",
		Region:   "cn",
		DeviceID: "dev-exp",
	})
	if err != nil {
		t.Fatal(err)
	}

	svc := NewTokenService(issuer, store.NewMemoryRevocationStore(), nil)
	_, err = svc.Refresh(context.Background(), pair.RefreshToken, "dev-exp")
	if err != ErrTokenExpired && err != ErrRefreshInvalid {
		t.Fatalf("expired refresh: got %v", err)
	}
}
