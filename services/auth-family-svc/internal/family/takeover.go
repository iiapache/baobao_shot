package family

import (
	"context"
	"errors"
	"math"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/google/uuid"
)

// TakeoverInput is the request payload for initiating or voting on a takeover.
type TakeoverInput struct {
	Choice string
}

// TakeoverResult is the current takeover vote state returned to clients.
type TakeoverResult struct {
	VoteID            string `json:"voteId"`
	Status            string `json:"status"`
	InitiatorUserID   string `json:"initiatorUserId"`
	EligibleVoters    int    `json:"eligibleVoters"`
	ApproveCount      int    `json:"approveCount"`
	RejectCount       int    `json:"rejectCount"`
	RequiredApprovals int    `json:"requiredApprovals"`
	ObjectionEndsAt   string `json:"objectionEndsAt,omitempty"`
}

// Takeover handles initiate / vote / object flows for admin takeover.
func (s *Service) Takeover(ctx context.Context, familyID, userID string, in TakeoverInput) (*TakeoverResult, error) {
	detail, err := s.store.GetFamilyDetail(ctx, familyID, userID)
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	activeVote, err := s.store.GetActiveTakeoverVote(ctx, familyID)
	if err != nil {
		return nil, err
	}

	if detail.Role == model.MemberRoleAdmin {
		if activeVote != nil && activeVote.Status == model.TakeoverStatusObjectionPeriod {
			if err := s.store.UpdateTakeoverVote(ctx, activeVote.ID, model.TakeoverStatusCancelled, nil, nil); err != nil {
				return nil, err
			}
			activeVote.Status = model.TakeoverStatusCancelled
			return s.buildTakeoverResult(ctx, detail.Members, activeVote)
		}
		return nil, ErrTakeoverNotEligible
	}
	if detail.Role == model.MemberRoleGuest {
		return nil, ErrTakeoverNotEligible
	}

	admin, err := s.store.FindByID(ctx, detail.Family.AdminUserID)
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if s.now().Sub(admin.LastSeenAt) < AdminInactiveDays*24*time.Hour {
		return nil, ErrAdminActive
	}

	choice, err := parseBallotChoice(in.Choice)
	if err != nil && activeVote == nil {
		choice = model.TakeoverBallotApprove
	} else if err != nil {
		return nil, err
	}

	if activeVote == nil {
		return s.initiateTakeover(ctx, familyID, userID, choice, detail.Members)
	}

	switch activeVote.Status {
	case model.TakeoverStatusVoting:
		return s.castTakeoverVote(ctx, activeVote, userID, choice, detail.Members)
	case model.TakeoverStatusObjectionPeriod:
		return s.buildTakeoverResult(ctx, detail.Members, activeVote)
	default:
		return nil, ErrTakeoverNoActiveVote
	}
}

// ProcessDueTakeovers completes takeover votes whose objection period has elapsed.
func (s *Service) ProcessDueTakeovers(ctx context.Context) (int, error) {
	now := s.now().UTC()
	due, err := s.store.ListDueTakeoverVotes(ctx, now)
	if err != nil {
		return 0, err
	}

	completed := 0
	for _, vote := range due {
		if err := s.store.CompleteTakeover(ctx, vote.ID, vote.InitiatorUserID, now); err != nil {
			return completed, err
		}
		completed++
	}
	return completed, nil
}

func (s *Service) initiateTakeover(
	ctx context.Context,
	familyID, initiatorUserID string,
	choice model.TakeoverBallotChoice,
	members []model.FamilyMember,
) (*TakeoverResult, error) {
	now := s.now().UTC()
	vote := model.TakeoverVote{
		ID:              "tov_" + uuid.NewString()[:12],
		FamilyID:        familyID,
		InitiatorUserID: initiatorUserID,
		Status:          model.TakeoverStatusVoting,
		OpensAt:         now,
		CreatedAt:       now,
	}
	created, err := s.store.CreateTakeoverVote(ctx, vote)
	if err != nil {
		if errors.Is(err, store.ErrTakeoverInProgress) {
			return nil, ErrTakeoverInProgress
		}
		return nil, err
	}
	if err := s.store.CastTakeoverBallot(ctx, created.ID, initiatorUserID, choice, now); err != nil {
		return nil, err
	}
	return s.evaluateTakeover(ctx, created, members)
}

func (s *Service) castTakeoverVote(
	ctx context.Context,
	vote *model.TakeoverVote,
	userID string,
	choice model.TakeoverBallotChoice,
	members []model.FamilyMember,
) (*TakeoverResult, error) {
	if !isEligibleVoter(members, userID) {
		return nil, ErrTakeoverNotEligible
	}

	ballots, err := s.store.ListTakeoverBallots(ctx, vote.ID)
	if err != nil {
		return nil, err
	}
	for _, b := range ballots {
		if b.UserID == userID {
			return nil, ErrTakeoverAlreadyVoted
		}
	}

	if err := s.store.CastTakeoverBallot(ctx, vote.ID, userID, choice, s.now().UTC()); err != nil {
		return nil, err
	}
	return s.evaluateTakeover(ctx, vote, members)
}

func (s *Service) evaluateTakeover(ctx context.Context, vote *model.TakeoverVote, members []model.FamilyMember) (*TakeoverResult, error) {
	ballots, err := s.store.ListTakeoverBallots(ctx, vote.ID)
	if err != nil {
		return nil, err
	}

	eligible := countEligibleVoters(members)
	required := requiredApprovals(eligible)
	approveCount, rejectCount := tallyBallots(ballots)

	if approveCount >= required && required > 0 {
		endsAt := s.now().UTC().Add(TakeoverObjectionDays * 24 * time.Hour)
		if err := s.store.UpdateTakeoverVote(ctx, vote.ID, model.TakeoverStatusObjectionPeriod, &endsAt, nil); err != nil {
			return nil, err
		}
		vote.Status = model.TakeoverStatusObjectionPeriod
		vote.EndsAt = &endsAt
	} else if eligible > 0 && approveCount+rejectCount >= eligible && approveCount < required {
		if err := s.store.UpdateTakeoverVote(ctx, vote.ID, model.TakeoverStatusRejected, nil, nil); err != nil {
			return nil, err
		}
		vote.Status = model.TakeoverStatusRejected
	}

	return s.buildTakeoverResult(ctx, members, vote)
}

func (s *Service) buildTakeoverResult(ctx context.Context, members []model.FamilyMember, vote *model.TakeoverVote) (*TakeoverResult, error) {
	ballots, err := s.store.ListTakeoverBallots(ctx, vote.ID)
	if err != nil {
		return nil, err
	}

	eligible := countEligibleVoters(members)
	approveCount, rejectCount := tallyBallots(ballots)
	result := &TakeoverResult{
		VoteID:            vote.ID,
		Status:            string(vote.Status),
		InitiatorUserID:   vote.InitiatorUserID,
		EligibleVoters:    eligible,
		ApproveCount:      approveCount,
		RejectCount:       rejectCount,
		RequiredApprovals: requiredApprovals(eligible),
	}
	if vote.EndsAt != nil && vote.Status == model.TakeoverStatusObjectionPeriod {
		result.ObjectionEndsAt = vote.EndsAt.UTC().Format(time.RFC3339)
	}
	return result, nil
}

func parseBallotChoice(raw string) (model.TakeoverBallotChoice, error) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "", "approve":
		return model.TakeoverBallotApprove, nil
	case "reject":
		return model.TakeoverBallotReject, nil
	default:
		return "", ErrInvalidChoice
	}
}

func isEligibleVoter(members []model.FamilyMember, userID string) bool {
	for _, m := range members {
		if m.UserID == userID && m.Role == model.MemberRoleFamily {
			return true
		}
	}
	return false
}

func countEligibleVoters(members []model.FamilyMember) int {
	count := 0
	for _, m := range members {
		if m.Role == model.MemberRoleFamily {
			count++
		}
	}
	return count
}

func requiredApprovals(eligible int) int {
	if eligible <= 0 {
		return 0
	}
	return int(math.Ceil(float64(eligible) * TakeoverApprovalRatio))
}

func tallyBallots(ballots []model.TakeoverBallot) (approve, reject int) {
	for _, b := range ballots {
		switch b.Choice {
		case model.TakeoverBallotApprove:
			approve++
		case model.TakeoverBallotReject:
			reject++
		}
	}
	return approve, reject
}
