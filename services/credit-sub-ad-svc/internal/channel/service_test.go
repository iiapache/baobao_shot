package channel

import (
	"context"
	"testing"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func TestGrantSignupCredits(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(credit.NewService(st))

	result, err := svc.GrantSignup(context.Background(), "usr_new")
	if err != nil {
		t.Fatalf("GrantSignup() error = %v", err)
	}
	if result.GrantedCredits != 100 {
		t.Fatalf("granted = %d, want 100", result.GrantedCredits)
	}
	if result.BalanceAfter != 100 {
		t.Fatalf("balance = %d, want 100", result.BalanceAfter)
	}

	dup, err := svc.GrantSignup(context.Background(), "usr_new")
	if err != nil {
		t.Fatalf("duplicate GrantSignup() error = %v", err)
	}
	if !dup.Duplicate || dup.GrantedCredits != 0 {
		t.Fatalf("duplicate = %+v, want duplicate with 0 grant", dup)
	}
}

func TestGrantProfileCompleteCredits(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(credit.NewService(st))

	result, err := svc.GrantProfileComplete(context.Background(), "usr_profile")
	if err != nil {
		t.Fatalf("GrantProfileComplete() error = %v", err)
	}
	if result.GrantedCredits != 20 || result.BalanceAfter != 20 {
		t.Fatalf("got %+v, want 20 credits", result)
	}
}

func TestGrantInviteCredits(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(credit.NewService(st))

	result, err := svc.GrantInvite(context.Background(), "usr_inviter", "usr_invitee")
	if err != nil {
		t.Fatalf("GrantInvite() error = %v", err)
	}
	if result.GrantedCredits != 50 || result.BalanceAfter != 50 {
		t.Fatalf("got %+v, want 50 credits", result)
	}

	second, err := svc.GrantInvite(context.Background(), "usr_inviter", "usr_invitee2")
	if err != nil {
		t.Fatalf("second GrantInvite() error = %v", err)
	}
	if second.GrantedCredits != 50 || second.BalanceAfter != 100 {
		t.Fatalf("second invite = %+v, want +50", second)
	}
}

func TestGrantInviteInvalidRequest(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(credit.NewService(st))

	if _, err := svc.GrantInvite(context.Background(), "", "usr_b"); err == nil {
		t.Fatal("expected invalid request")
	}
}
