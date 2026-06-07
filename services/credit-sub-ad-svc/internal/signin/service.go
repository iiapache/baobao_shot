package signin

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

const ledgerRefKind = "sign_in"

// Service handles daily sign-in grants with streak-based credits.
type Service struct {
	signIns store.SignInStore
	ledger  *credit.Service
	now     func() time.Time
}

// NewService creates a sign-in service.
func NewService(st store.SignInStore, ledger *credit.Service) *Service {
	return &Service{
		signIns: st,
		ledger:  ledger,
		now:     time.Now,
	}
}

// SetNow overrides the clock (tests only).
func (s *Service) SetNow(fn func() time.Time) {
	if fn != nil {
		s.now = fn
	}
}

// Result is returned after a successful sign-in.
type Result struct {
	GrantedCredits int64
	BalanceAfter   int64
	Streak         int
	LedgerID       string
}

// SignIn grants daily credits when the user has not signed in today (UTC).
func (s *Service) SignIn(ctx context.Context, userID string) (Result, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return Result{}, ErrInvalidRequest
	}

	today := utcDate(s.now())
	if s.signIns != nil {
		done, err := s.signIns.HasSignedIn(ctx, userID, today)
		if err != nil {
			return Result{}, err
		}
		if done {
			return Result{}, ErrSignInDone
		}
	}

	streak := 1
	if s.signIns != nil {
		yesterday := today.AddDate(0, 0, -1)
		if prev, err := s.signIns.GetSignIn(ctx, userID, yesterday); err == nil {
			streak = prev.Streak + 1
		} else if !errors.Is(err, store.ErrNotFound) {
			return Result{}, err
		}
	}

	credits := CreditsForStreak(streak)
	refID := today.Format("2006-01-02")

	if s.signIns != nil {
		inserted, err := s.signIns.RecordSignIn(ctx, model.SignInRecord{
			UserID:         userID,
			Date:           today,
			CreditsGranted: credits,
			Streak:         streak,
		})
		if err != nil {
			return Result{}, err
		}
		if !inserted {
			return Result{}, ErrSignInDone
		}
	}

	grant, err := s.ledger.Grant(ctx, userID, credits, ledgerRefKind, refID)
	if err != nil {
		return Result{}, err
	}

	return Result{
		GrantedCredits: credits,
		BalanceAfter:   grant.Entry.BalanceAfter,
		Streak:         streak,
		LedgerID:       grant.Entry.ID,
	}, nil
}

func utcDate(t time.Time) time.Time {
	utc := t.UTC()
	return time.Date(utc.Year(), utc.Month(), utc.Day(), 0, 0, 0, 0, time.UTC)
}
