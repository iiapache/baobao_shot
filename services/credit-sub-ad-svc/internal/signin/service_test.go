package signin

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func TestSignInFirstDayGrantsFive(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st, credit.NewService(st))
	svc.SetNow(func() time.Time {
		return time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	})

	result, err := svc.SignIn(context.Background(), "usr_sign")
	if err != nil {
		t.Fatalf("SignIn() error = %v", err)
	}
	if result.GrantedCredits != 5 {
		t.Fatalf("granted = %d, want 5", result.GrantedCredits)
	}
	if result.Streak != 1 {
		t.Fatalf("streak = %d, want 1", result.Streak)
	}
	if result.BalanceAfter != 5 {
		t.Fatalf("balance = %d, want 5", result.BalanceAfter)
	}
}

func TestSignInStreakIncreasesCredits(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st, credit.NewService(st))
	day1 := time.Date(2026, 6, 5, 8, 0, 0, 0, time.UTC)
	day2 := time.Date(2026, 6, 6, 8, 0, 0, 0, time.UTC)

	if _, err := st.RecordSignIn(context.Background(), model.SignInRecord{
		UserID: "usr_streak", Date: day1, CreditsGranted: 5, Streak: 1,
	}); err != nil {
		t.Fatal(err)
	}
	svc.SetNow(func() time.Time { return day2 })

	result, err := svc.SignIn(context.Background(), "usr_streak")
	if err != nil {
		t.Fatalf("SignIn() error = %v", err)
	}
	if result.GrantedCredits != 6 {
		t.Fatalf("granted = %d, want 6", result.GrantedCredits)
	}
	if result.Streak != 2 {
		t.Fatalf("streak = %d, want 2", result.Streak)
	}
}

func TestSignInBrokenStreakResets(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st, credit.NewService(st))
	if _, err := st.RecordSignIn(context.Background(), model.SignInRecord{
		UserID: "usr_reset", Date: time.Date(2026, 6, 4, 0, 0, 0, 0, time.UTC), CreditsGranted: 10, Streak: 6,
	}); err != nil {
		t.Fatal(err)
	}
	svc.SetNow(func() time.Time {
		return time.Date(2026, 6, 6, 9, 0, 0, 0, time.UTC)
	})

	result, err := svc.SignIn(context.Background(), "usr_reset")
	if err != nil {
		t.Fatalf("SignIn() error = %v", err)
	}
	if result.GrantedCredits != 5 || result.Streak != 1 {
		t.Fatalf("got %+v, want 5 credits streak 1", result)
	}
}

func TestSignInDuplicateSameDay(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st, credit.NewService(st))
	fixed := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc.SetNow(func() time.Time { return fixed })

	if _, err := svc.SignIn(context.Background(), "usr_dup"); err != nil {
		t.Fatalf("first SignIn() error = %v", err)
	}
	_, err := svc.SignIn(context.Background(), "usr_dup")
	if err == nil {
		t.Fatal("expected duplicate sign-in error")
	}
	if !errors.Is(err, ErrSignInDone) {
		t.Fatalf("error = %v, want ErrSignInDone", err)
	}
}

func TestSignInCapsAtTwenty(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st, credit.NewService(st))
	if _, err := st.RecordSignIn(context.Background(), model.SignInRecord{
		UserID: "usr_cap", Date: time.Date(2026, 6, 5, 0, 0, 0, 0, time.UTC), CreditsGranted: 19, Streak: 15,
	}); err != nil {
		t.Fatal(err)
	}
	svc.SetNow(func() time.Time {
		return time.Date(2026, 6, 6, 0, 0, 0, 0, time.UTC)
	})

	result, err := svc.SignIn(context.Background(), "usr_cap")
	if err != nil {
		t.Fatalf("SignIn() error = %v", err)
	}
	if result.GrantedCredits != 20 || result.Streak != 16 {
		t.Fatalf("got %+v, want 20 credits streak 16", result)
	}
}
