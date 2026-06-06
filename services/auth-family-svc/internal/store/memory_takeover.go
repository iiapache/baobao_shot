package store

import (
	"context"
	"fmt"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *MemoryStore) TransferAdmin(_ context.Context, familyID, fromUserID, toUserID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	f, ok := s.families[familyID]
	if !ok {
		return ErrNotFound
	}
	if f.AdminUserID != fromUserID {
		return fmt.Errorf("not admin")
	}

	toMembership, ok := activeMembershipLocked(s, toUserID, familyID)
	if !ok || toMembership.Role != model.MemberRoleFamily {
		return fmt.Errorf("invalid transfer target")
	}
	fromMembership, ok := activeMembershipLocked(s, fromUserID, familyID)
	if !ok || fromMembership.Role != model.MemberRoleAdmin {
		return fmt.Errorf("not admin")
	}

	f.AdminUserID = toUserID
	fromMembership.Role = model.MemberRoleFamily
	toMembership.Role = model.MemberRoleAdmin
	return nil
}

func (s *MemoryStore) CreateTakeoverVote(_ context.Context, vote model.TakeoverVote) (*model.TakeoverVote, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, existing := range s.takeoverVotes {
		if existing.FamilyID == vote.FamilyID && isActiveTakeoverStatus(existing.Status) {
			return nil, ErrTakeoverInProgress
		}
	}

	copy := vote
	if copy.CreatedAt.IsZero() {
		copy.CreatedAt = time.Now().UTC()
	}
	if copy.OpensAt.IsZero() {
		copy.OpensAt = copy.CreatedAt
	}
	s.takeoverVotes[copy.ID] = cloneTakeoverVote(&copy)
	if s.takeoverBallots[copy.ID] == nil {
		s.takeoverBallots[copy.ID] = make(map[string]*model.TakeoverBallot)
	}
	return cloneTakeoverVote(&copy), nil
}

func (s *MemoryStore) GetActiveTakeoverVote(_ context.Context, familyID string) (*model.TakeoverVote, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, vote := range s.takeoverVotes {
		if vote.FamilyID == familyID && isActiveTakeoverStatus(vote.Status) {
			return cloneTakeoverVote(vote), nil
		}
	}
	return nil, nil
}

func (s *MemoryStore) CastTakeoverBallot(_ context.Context, voteID, userID string, choice model.TakeoverBallotChoice, votedAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	vote, ok := s.takeoverVotes[voteID]
	if !ok {
		return ErrNotFound
	}
	if vote.Status != model.TakeoverStatusVoting {
		return fmt.Errorf("vote not open")
	}
	if s.takeoverBallots[voteID] == nil {
		s.takeoverBallots[voteID] = make(map[string]*model.TakeoverBallot)
	}
	if _, exists := s.takeoverBallots[voteID][userID]; exists {
		return ErrTakeoverAlreadyVoted
	}

	s.takeoverBallots[voteID][userID] = &model.TakeoverBallot{
		VoteID:  voteID,
		UserID:  userID,
		Choice:  choice,
		VotedAt: votedAt.UTC(),
	}
	return nil
}

func (s *MemoryStore) ListTakeoverBallots(_ context.Context, voteID string) ([]model.TakeoverBallot, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	byUser := s.takeoverBallots[voteID]
	out := make([]model.TakeoverBallot, 0, len(byUser))
	for _, ballot := range byUser {
		copy := *ballot
		out = append(out, copy)
	}
	return out, nil
}

func (s *MemoryStore) UpdateTakeoverVote(_ context.Context, voteID string, status model.TakeoverVoteStatus, endsAt, completedAt *time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	vote, ok := s.takeoverVotes[voteID]
	if !ok {
		return ErrNotFound
	}
	vote.Status = status
	if endsAt != nil {
		t := endsAt.UTC()
		vote.EndsAt = &t
	}
	if completedAt != nil {
		t := completedAt.UTC()
		vote.CompletedAt = &t
	}
	return nil
}

func (s *MemoryStore) ListDueTakeoverVotes(_ context.Context, before time.Time) ([]model.TakeoverVote, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make([]model.TakeoverVote, 0)
	for _, vote := range s.takeoverVotes {
		if vote.Status != model.TakeoverStatusObjectionPeriod || vote.EndsAt == nil {
			continue
		}
		if !vote.EndsAt.After(before) {
			out = append(out, *cloneTakeoverVote(vote))
		}
	}
	return out, nil
}

func (s *MemoryStore) CompleteTakeover(_ context.Context, voteID, newAdminUserID string, completedAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	vote, ok := s.takeoverVotes[voteID]
	if !ok {
		return ErrNotFound
	}
	f, ok := s.families[vote.FamilyID]
	if !ok {
		return ErrNotFound
	}

	oldAdminID := f.AdminUserID
	if oldAdminID == newAdminUserID {
		return fmt.Errorf("invalid transfer target")
	}

	toMembership, ok := activeMembershipLocked(s, newAdminUserID, vote.FamilyID)
	if !ok || toMembership.Role != model.MemberRoleFamily {
		return fmt.Errorf("invalid transfer target")
	}
	fromMembership, ok := activeMembershipLocked(s, oldAdminID, vote.FamilyID)
	if !ok || fromMembership.Role != model.MemberRoleAdmin {
		return fmt.Errorf("not admin")
	}

	f.AdminUserID = newAdminUserID
	fromMembership.Role = model.MemberRoleFamily
	toMembership.Role = model.MemberRoleAdmin

	t := completedAt.UTC()
	vote.Status = model.TakeoverStatusCompleted
	vote.CompletedAt = &t
	return nil
}

// SetUserLastSeen updates last_seen_at for tests and seeding.
func (s *MemoryStore) SetUserLastSeen(_ context.Context, userID string, at time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	user, ok := s.users[userID]
	if !ok || user.DeletedAt != nil {
		return ErrNotFound
	}
	t := at.UTC()
	user.LastSeenAt = t
	user.UpdatedAt = t
	return nil
}

func isActiveTakeoverStatus(status model.TakeoverVoteStatus) bool {
	return status == model.TakeoverStatusVoting || status == model.TakeoverStatusObjectionPeriod
}

func cloneTakeoverVote(vote *model.TakeoverVote) *model.TakeoverVote {
	if vote == nil {
		return nil
	}
	copy := *vote
	if vote.EndsAt != nil {
		t := *vote.EndsAt
		copy.EndsAt = &t
	}
	if vote.CompletedAt != nil {
		t := *vote.CompletedAt
		copy.CompletedAt = &t
	}
	return &copy
}
