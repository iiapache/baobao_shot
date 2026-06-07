package channel

import (
	"context"
	"strings"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
)

const (
	RefKindSignup          = "signup"
	RefKindProfileComplete = "profile_complete"
	RefKindInvite          = "invite"

	SignupCredits          int64 = 100
	ProfileCompleteCredits int64 = 20
	InviteCredits          int64 = 50
)

// Service grants one-time or repeatable channel bonuses via the ledger.
type Service struct {
	ledger *credit.Service
}

// NewService creates a channel grant service.
func NewService(ledger *credit.Service) *Service {
	return &Service{ledger: ledger}
}

// Result is returned after a channel grant attempt.
type Result struct {
	GrantedCredits int64
	BalanceAfter   int64
	LedgerID       string
	Duplicate      bool
}

// GrantSignup awards new-user registration credits (100, once per user).
func (s *Service) GrantSignup(ctx context.Context, userID string) (Result, error) {
	return s.grant(ctx, userID, SignupCredits, RefKindSignup, userID)
}

// GrantProfileComplete awards baby profile completion credits (20, once per user).
func (s *Service) GrantProfileComplete(ctx context.Context, userID string) (Result, error) {
	return s.grant(ctx, userID, ProfileCompleteCredits, RefKindProfileComplete, userID)
}

// GrantInvite awards invite credits (50) to inviter when invitee is verified.
func (s *Service) GrantInvite(ctx context.Context, inviterID, inviteeID string) (Result, error) {
	inviterID = strings.TrimSpace(inviterID)
	inviteeID = strings.TrimSpace(inviteeID)
	if inviterID == "" || inviteeID == "" {
		return Result{}, ErrInvalidRequest
	}
	return s.grant(ctx, inviterID, InviteCredits, RefKindInvite, inviteeID)
}

func (s *Service) grant(ctx context.Context, userID string, amount int64, refKind, refID string) (Result, error) {
	userID = strings.TrimSpace(userID)
	refID = strings.TrimSpace(refID)
	if userID == "" || refID == "" {
		return Result{}, ErrInvalidRequest
	}

	grant, err := s.ledger.Grant(ctx, userID, amount, refKind, refID)
	if err != nil {
		return Result{}, err
	}

	granted := amount
	if grant.Duplicate {
		granted = 0
	}
	return Result{
		GrantedCredits: granted,
		BalanceAfter:   grant.Entry.BalanceAfter,
		LedgerID:       grant.Entry.ID,
		Duplicate:      grant.Duplicate,
	}, nil
}
